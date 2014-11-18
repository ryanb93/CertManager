/*
 * Copyright (c) 2003-2004,2006-2010 Apple Inc. All Rights Reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 *
 * OTATrustUtilities.c
 */

#include <Securityd/OTATrustUtilities.h>

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/syslimits.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <CoreFoundation/CoreFoundation.h>
#include <ftw.h>
#include <Securityd/SecFramework.h>
#include <pthread.h>
#include <sys/param.h>
#include <stdlib.h>
#include <Securityd/SecCFRelease.h>
#include <Securityd/CFRuntime.h>
//#include "SecCFError.h"
#include <Securityd/SecCFWrappers.h>
#include <Securityd/SecBasePriv.h>
#include <dispatch/dispatch.h>
#include <CommonCrypto/CommonDigest.h>


//#define NEW_LOCATION 1

#if NEW_LOCATION
static const char*  kBaseAssertDirectory = "/var/OTAPKI/Assets";
#else
static const char*	kBaseAssertDirectory = "/var/Keychains/Assets";
#endif

static const char*	kVersionDirectoryNamePrefix = "Version_";
static const char*	kNumberString = "%d";

struct index_record
{
    unsigned char hash[CC_SHA1_DIGEST_LENGTH];
    uint32_t offset;
};
typedef struct index_record index_record;


struct _OpaqueSecOTAPKI 
{
	CFRuntimeBase 		_base;
	CFSetRef			_blackListSet;
	CFSetRef			_grayListSet;
	CFArrayRef			_escrowCertificates;
	CFDictionaryRef		_evPolicyToAnchorMapping;
	CFDictionaryRef		_anchorLookupTable;
	const char*			_anchorTable;
	int					_assetVersion;
};

CFGiblisFor(SecOTAPKI)

static CF_RETURNS_RETAINED CFStringRef SecOTAPKICopyDescription(CFTypeRef cf) 
{
    SecOTAPKIRef otapkiRef = (SecOTAPKIRef)cf;
    return CFStringCreateWithFormat(kCFAllocatorDefault,NULL,CFSTR("<SecOTAPKIRef: version %d>"), otapkiRef->_assetVersion);
}

static void SecOTAPKIDestroy(CFTypeRef cf) 
{
    SecOTAPKIRef otapkiref = (SecOTAPKIRef)cf;
    
    CFReleaseNull(otapkiref->_blackListSet);
    CFReleaseNull(otapkiref->_grayListSet);
    CFReleaseNull(otapkiref->_escrowCertificates);
    
    CFReleaseNull(otapkiref->_evPolicyToAnchorMapping);
    CFReleaseNull(otapkiref->_anchorLookupTable);

	free((void *)otapkiref->_anchorTable);
}

CFDataRef SecOTACopyFileContents(const char *path)
{
    CFMutableDataRef data = NULL;
    int fd = open(path, O_RDONLY, 0666);

    if (fd == -1) 
	{
        goto badFile;
    }

    off_t fsize = lseek(fd, 0, SEEK_END);
    if (fsize == (off_t)-1) 
	{
        goto badFile;
    }

	if (fsize > (off_t)INT32_MAX) 
	{
		goto badFile;
	}

    data = CFDataCreateMutable(kCFAllocatorDefault, (CFIndex)fsize);
	if (NULL == data)
	{
		goto badFile;
	}
	
    CFDataSetLength(data, (CFIndex)fsize);
    void *buf = CFDataGetMutableBytePtr(data);
	if (NULL == buf)
	{
		goto badFile;
	}
	
    off_t total_read = 0;
    while (total_read < fsize) 
	{
        ssize_t bytes_read;

        bytes_read = pread(fd, buf, (size_t)(fsize - total_read), total_read);
        if (bytes_read == -1) 
		{
            goto badFile;
        }
        if (bytes_read == 0) 
		{
            goto badFile;
        }
        total_read += bytes_read;
    }

	close(fd);
    return data;

badFile:
    if (fd != -1) 
	{
		close(fd);
    }

    if (data)
	{	
		CFRelease(data);
	}
        
    return NULL;
}

static Boolean PathExists(const char* path, size_t* pFileSize)
{
	Boolean result = false;
	struct stat         sb;
	
	if (NULL != pFileSize)
	{
		*pFileSize = 0;
	}
	
	int stat_result = stat(path, &sb);
	result = (stat_result == 0);
	
    
    if (result)
    {
        if (S_ISDIR(sb.st_mode))
        {
            // It is a directory
            ;
        }
        else
        {
            // It is a file
            if (NULL != pFileSize)
            {
                *pFileSize = (size_t)sb.st_size;
            }
        }
    }
	
	return result;
}

static int unlink_cb(const char *fpath, const struct stat *sb, int typeflag, struct FTW *ftwbuf)
{
    int rv = remove(fpath); 
    return rv;
}

static int rmrf(char *path)
{
	const char* p1 = NULL;
	char path_buffer[PATH_MAX];
	memset(path_buffer, 0, sizeof(path_buffer));
	
	p1 = realpath(path, path_buffer);
	if (!strncmp(path, p1, PATH_MAX))
	{
		return nftw(path, unlink_cb, 64, FTW_DEPTH | FTW_PHYS);
	}
	return -1;
}

int InitOTADirectory()
{
	char buffer[PATH_MAX];
    DIR *dp;
    struct dirent *ep;
    int version = 0;
    static int current_version = 0;
    CFIndex asset_number = 0;
    
	bool assetDirectoryExists = PathExists(kBaseAssertDirectory, NULL);
    if (assetDirectoryExists)
    {
		dp = opendir (kBaseAssertDirectory);
		if (NULL != dp)
		{
			while ((ep = readdir(dp)))
			{
				if (strstr(ep->d_name, kVersionDirectoryNamePrefix))
				{
					memset(buffer, 0, sizeof(buffer));
					snprintf(buffer,  sizeof(buffer), "%s%s", kVersionDirectoryNamePrefix, kNumberString);

					sscanf(ep->d_name, buffer, &version);
					

					if (current_version > 0)
					{
						if (version > current_version)
						{
							// There is more than one Version_ directory.
							// Delete the one with the smaller version number
							memset(buffer, 0, sizeof(buffer));
							snprintf(buffer,  sizeof(buffer), "%s/%s%d", kBaseAssertDirectory, kVersionDirectoryNamePrefix, current_version);
							if (PathExists(buffer, NULL))
							{
								rmrf(buffer);
							}
							current_version = version;
						}
					}
					else
					{
						current_version = version;
					}
				}
			}
			closedir(dp);
		}
		else
		{
		}
	}
	else
	{
	}
    
	memset(buffer, 0, sizeof(buffer));
   
    if (0 == current_version)
    {
        // No Assets are installed so get the Asset Verson from the AssertVersion.plist in the Security.framework
        
        // Look in the resources for a AssetVerstion.plst file
        
        CFDataRef assetVersionData = SecFrameworkCopyResourceContents(CFSTR("AssetVersion"), CFSTR("plist"), NULL);
        if (NULL != assetVersionData)
        {
            CFPropertyListFormat propFormat;
            CFDictionaryRef versionPlist =  CFPropertyListCreateWithData(kCFAllocatorDefault, assetVersionData, 0, &propFormat, NULL);
            if (NULL != versionPlist && CFDictionaryGetTypeID() == CFGetTypeID(versionPlist))
            {
                CFNumberRef versionNumber = (CFNumberRef)CFDictionaryGetValue(versionPlist, (const void *)CFSTR("VersionNumber"));
                if (NULL != versionNumber)
                {                    
					CFNumberGetValue(versionNumber, kCFNumberCFIndexType, &asset_number);
                }
            }
		    CFReleaseSafe(versionPlist);
            CFReleaseSafe(assetVersionData);
        }
        
        current_version = (int)asset_number;
    }
	
	return current_version;
}

static CFSetRef InitializeBlackList(const char* path_ptr)
{
	CFSetRef result = NULL;

	// Check to see if the EVRoots.plist file is in the asset location
	CFDataRef xmlData = NULL;
	const char* asset_path = path_ptr;
	if (NULL == asset_path)
	{
		// There is no OTA asset file so use the file in the Sercurity.framework bundle
		xmlData = SecFrameworkCopyResourceContents(CFSTR("Blocked"), CFSTR("plist"), NULL);
	}
	else
	{
		char file_path_buffer[PATH_MAX];
		memset(file_path_buffer, 0, PATH_MAX);
		snprintf(file_path_buffer, PATH_MAX, "%s/Blocked.plist", asset_path);
        
        xmlData = SecOTACopyFileContents(file_path_buffer);
        
		if (NULL == xmlData)
		{
            xmlData = SecFrameworkCopyResourceContents(CFSTR("Blocked"), CFSTR("plist"), NULL);
		}
	}

	CFPropertyListRef blackKeys = NULL;
    if (xmlData)
	{
        blackKeys = CFPropertyListCreateWithData(kCFAllocatorDefault, xmlData, kCFPropertyListImmutable, NULL, NULL);
        CFRelease(xmlData);
    }

	if (blackKeys)
	{
		CFMutableSetRef tempSet = NULL;
		if (CFGetTypeID(blackKeys) == CFArrayGetTypeID())
		{
			tempSet = CFSetCreateMutable(kCFAllocatorDefault, 0, &kCFTypeSetCallBacks);
			if (NULL == tempSet)
			{
				CFRelease(blackKeys);
				return result;
			}
			CFArrayRef blackKeyArray = (CFArrayRef)blackKeys;
			CFIndex num_keys = CFArrayGetCount(blackKeyArray);
			for (CFIndex idx = 0; idx < num_keys; idx++)
			{
				CFDataRef key_data = (CFDataRef)CFArrayGetValueAtIndex(blackKeyArray, idx);
				CFSetAddValue(tempSet, key_data);
			}
		}
		else
		{
			CFRelease(blackKeys);
			return result;
		}

		if (NULL != tempSet)
		{
			result = tempSet;
		}
		CFRelease(blackKeys);
    }

	return result;
}

static CFSetRef InitializeGrayList(const char* path_ptr)
{
	CFSetRef result = NULL;
	
	// Check to see if the EVRoots.plist file is in the asset location
	CFDataRef xmlData = NULL;
	const char* asset_path = path_ptr;
	if (NULL == asset_path)
	{
		// There is no updated asset file so use the file in the Sercurity.framework bundle
		xmlData = SecFrameworkCopyResourceContents(CFSTR("GrayListedKeys"), CFSTR("plist"), NULL);
	}
	else
	{
		char file_path_buffer[PATH_MAX];
		memset(file_path_buffer, 0, PATH_MAX);
		snprintf(file_path_buffer, PATH_MAX, "%s/GrayListedKeys.plist", asset_path);

        xmlData = SecOTACopyFileContents(file_path_buffer);
        
		if (NULL == xmlData)
		{
            xmlData = SecFrameworkCopyResourceContents(CFSTR("GrayListedKeys"), CFSTR("plist"), NULL); 
        }
	}

	CFPropertyListRef grayKeys = NULL;
    if (xmlData)
	{
        grayKeys = CFPropertyListCreateWithData(kCFAllocatorDefault, xmlData, kCFPropertyListImmutable, NULL, NULL);
        CFRelease(xmlData);
    }

	if (grayKeys)
	{
		CFMutableSetRef tempSet = NULL;
		if (CFGetTypeID(grayKeys) == CFArrayGetTypeID())
		{
			tempSet = CFSetCreateMutable(kCFAllocatorDefault, 0, &kCFTypeSetCallBacks);
			if (NULL == tempSet)
			{
				CFRelease(grayKeys);
				return result;
			}
			CFArrayRef grayKeyArray = (CFArrayRef)grayKeys;
			CFIndex num_keys = CFArrayGetCount(grayKeyArray);
			for (CFIndex idx = 0; idx < num_keys; idx++)
			{
				CFDataRef key_data = (CFDataRef)CFArrayGetValueAtIndex(grayKeyArray, idx);
				CFSetAddValue(tempSet, key_data);
			}
		}
		else
		{
			CFRelease(grayKeys);
			return result;
		}

		if (NULL != tempSet)
		{
			result = tempSet;
		}
	
		CFRelease(grayKeys);
    }
	return result;
}

static CFDictionaryRef InitializeEVPolicyToAnchorDigestsTable(const char* path_ptr)
{
	CFDictionaryRef result = NULL;

	// Check to see if the EVRoots.plist file is in the asset location
	CFDataRef xmlData = NULL;
	const char* asset_path = path_ptr;
	if (NULL == asset_path)
	{
		// There is no updated asset file so use the file in the Sercurity.framework bundle
		xmlData = SecFrameworkCopyResourceContents(CFSTR("EVRoots"), CFSTR("plist"), NULL);
	}
	else
	{
        char file_path_buffer[PATH_MAX];
        memset(file_path_buffer, 0, PATH_MAX);
        snprintf(file_path_buffer, PATH_MAX, "%s/EVRoots.plist", asset_path);

        xmlData = SecOTACopyFileContents(file_path_buffer);
        
		if (NULL == xmlData)
		{
			xmlData = SecFrameworkCopyResourceContents(CFSTR("EVRoots"), CFSTR("plist"), NULL);
		}
	}
	
	CFPropertyListRef evroots = NULL;
    if (xmlData) 
	{
        evroots = CFPropertyListCreateWithData(
            kCFAllocatorDefault, xmlData, kCFPropertyListImmutable, NULL, NULL);
        CFRelease(xmlData);
    }

	if (evroots) 
	{
		if (CFGetTypeID(evroots) == CFDictionaryGetTypeID()) 
		{
            /* @@@ Ensure that each dictionary key is a dotted list of digits,
               each value is an NSArrayRef and each element in the array is a
               20 byte digest. */

			result = (CFDictionaryRef)evroots;
		} 
		else 
		{
//			secwarning("EVRoot.plist is wrong type.");
			CFRelease(evroots);
		}
    }

	return result;
}

void* MapFile(const char* path, int* out_fd, size_t* out_file_size)
{     
	void* result = NULL;
	void* temp_result = NULL;
	if (NULL == path || NULL == out_fd || NULL == out_file_size)
	{
		return result;
	}
	
	*out_fd = -1;
	*out_file_size = 0;
	
	
	*out_fd  = open(path, O_RDONLY, 0666);

    if (*out_fd == -1) 
	{
       	return result;
    }

    off_t fsize = lseek(*out_fd, 0, SEEK_END);
    if (fsize == (off_t)-1) 
	{
       	return result;
    }

	if (fsize > (off_t)INT32_MAX) 
	{
		close(*out_fd);
		*out_fd = -1;
       	return result;
	}
	
	size_t malloc_size = (size_t)fsize;
		
	temp_result = malloc(malloc_size);
	if (NULL == temp_result)
	{
		close(*out_fd);
		*out_fd = -1;
		return result;
	}
	
	*out_file_size = malloc_size;
	
	off_t total_read = 0;
    while (total_read < fsize) 
	{
        ssize_t bytes_read;

        bytes_read = pread(*out_fd, temp_result, (size_t)(fsize - total_read), total_read);
        if (bytes_read == -1) 
		{
			free(temp_result);
			temp_result = NULL;
            close(*out_fd);
			*out_fd = -1;
	       	return result;
        }
        if (bytes_read == 0) 
		{
            free(temp_result);
			temp_result = NULL;
            close(*out_fd);
			*out_fd = -1;
	       	return result;
        }
        total_read += bytes_read;
    }
	
	if (NULL != temp_result)
    {
		result =  temp_result;
    }

	return result;
}

static void UnMapFile(void* mapped_data, size_t data_size)
{
#pragma unused(mapped_data, data_size)
	if (NULL != mapped_data)
	{
		free((void *)mapped_data);
		mapped_data = NULL;
	}
}

static bool InitializeAnchorTable(const char* path_ptr, CFDictionaryRef* pLookupTable, const char** ppAnchorTable)
{
	
	bool result = false;
	
	if (NULL == pLookupTable || NULL == ppAnchorTable)
	{
		return result;
	}
	
	*pLookupTable = NULL;
	*ppAnchorTable = NULL;;
	
    // first see if there is a file at /var/db/OTA_Anchors
    const char*         	dir_path = NULL;
	CFDataRef				cert_index_file_data = NULL;
	char 					file_path_buffer[PATH_MAX];
	CFURLRef 				table_data_url = NULL;
	CFStringRef				table_data_cstr_path = NULL;
	const char*				table_data_path = NULL;
	const index_record*     pIndex = NULL;
	size_t              	index_offset = 0;
	size_t					index_data_size = 0;
	CFMutableDictionaryRef 	anchorLookupTable = NULL;
	uint32_t 				offset_int_value = 0;
	CFNumberRef         	index_offset_value = NULL;
	CFDataRef           	index_hash = NULL;
	CFMutableArrayRef   	offsets = NULL;
	Boolean					release_offset = false;
	
	char* local_anchorTable = NULL;
	size_t local_anchorTableSize = 0;
	int local_anchorTable_fd = -1;
    
	// ------------------------------------------------------------------------
	// First determine if there are asset files at /var/Keychains.  If there 
	// are files use them for the trust table.  Otherwise, use the files in the
	// Security.framework bundle.
	//
	// The anchor table file is mapped into memory. This SHOULD be OK as the
	// size of the data is around 250K.
	// ------------------------------------------------------------------------
	dir_path = path_ptr;
	
//	if (NULL != dir_path)
//	{
//		// There is a set of OTA asset files
//		memset(file_path_buffer, 0, PATH_MAX);
//		snprintf(file_path_buffer, PATH_MAX, "%s/certsIndex.data", dir_path);
//        cert_index_file_data = SecOTACopyFileContents(file_path_buffer);
//        
//		if (NULL != cert_index_file_data)
//		{
//			memset(file_path_buffer, 0, PATH_MAX);
//			snprintf(file_path_buffer, PATH_MAX, "%s/certsTable.data", dir_path);
//            local_anchorTable  = (char *)MapFile(file_path_buffer, &local_anchorTable_fd, &local_anchorTableSize);
//        }
//
////		free((void *)dir_path);
//        dir_path = NULL;
//	}
	
	// Check to see if kAnchorTable was indeed set
	if (NULL == local_anchorTable)
    {  
		// local_anchorTable is still NULL so the asset in the Security framework needs to be used.
        CFReleaseSafe(cert_index_file_data);
        cert_index_file_data = SecFrameworkCopyResourceContents(CFSTR("certsIndex"), CFSTR("data"), NULL);
        table_data_url =  SecFrameworkCopyResourceURL(CFSTR("certsTable"), CFSTR("data"), NULL);
        if (NULL != table_data_url)
        {
            table_data_cstr_path  = CFURLCopyFileSystemPath(table_data_url, kCFURLPOSIXPathStyle);
            if (NULL != table_data_cstr_path)
            {
                memset(file_path_buffer, 0, PATH_MAX);
                table_data_path = CFStringGetCStringPtr(table_data_cstr_path, kCFStringEncodingUTF8);
                if (NULL == table_data_path)
                {
                    if (CFStringGetCString(table_data_cstr_path, file_path_buffer, PATH_MAX, kCFStringEncodingUTF8))
                    {
                        table_data_path = file_path_buffer;
                    }
                }
                local_anchorTable  = (char *)MapFile(table_data_path, &local_anchorTable_fd, &local_anchorTableSize);
                CFReleaseSafe(table_data_cstr_path);
            }
        }
		CFReleaseSafe(table_data_url);
 	}
		
	if (NULL == local_anchorTable || NULL  == cert_index_file_data)
	{
		// we are in trouble
		CFReleaseSafe(cert_index_file_data);
		return result;
	}

	// ------------------------------------------------------------------------
	// Now that the locations of the files are known and the table file has
	// been mapped into memory, create a dictionary that maps the SHA1 hash of
	// normalized issuer to the offset in the mapped anchor table file which
	// contains a index_record to the correct certificate
	// ------------------------------------------------------------------------
	pIndex = (const index_record*)CFDataGetBytePtr(cert_index_file_data);
	index_data_size = CFDataGetLength(cert_index_file_data);

    anchorLookupTable = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, 
		&kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

    for (index_offset = index_data_size; index_offset > 0; index_offset -= sizeof(index_record), pIndex++)
    {
        offset_int_value = pIndex->offset;

        index_offset_value = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &offset_int_value);
        index_hash = CFDataCreate(kCFAllocatorDefault, pIndex->hash, CC_SHA1_DIGEST_LENGTH);

        // see if the dictionary already has this key
		release_offset = false;
        offsets = (CFMutableArrayRef)CFDictionaryGetValue(anchorLookupTable, index_hash);
        if (NULL == offsets)
        {
			offsets = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
			release_offset = true;
        }

        // Add the offset
        CFArrayAppendValue(offsets, index_offset_value);

        // set the key value pair in the dictionary
        CFDictionarySetValue(anchorLookupTable, index_hash, offsets);

        CFRelease(index_offset_value);
        CFRelease(index_hash);
		if (release_offset)
		{
			CFRelease(offsets);
		}
     }

    CFRelease(cert_index_file_data);
    
    if (NULL != anchorLookupTable && NULL != local_anchorTable)
    {
		*pLookupTable = anchorLookupTable;
		*ppAnchorTable = local_anchorTable;
		result = true;
    }
    else
    {
		CFReleaseSafe(anchorLookupTable);
        if (NULL != local_anchorTable)
        {
			UnMapFile(local_anchorTable, local_anchorTableSize);
            //munmap(kAnchorTable, local_anchorTableSize);
            local_anchorTable = NULL;
            local_anchorTableSize = 0;
        }
    }
	
	return result;	
}

static CFArrayRef InitializeEscrowCertificates(const char* path_ptr)
{	
	CFArrayRef result = NULL;
	CFDataRef file_data = NULL;
	
	const char* dir_path = path_ptr;
	if (NULL == dir_path)
	{
		file_data = SecFrameworkCopyResourceContents(CFSTR("AppleESCertificates"), CFSTR("plist"), NULL);
	}
	else
	{
		char buffer[1024];
		memset(buffer, 0, 1024);
		snprintf(buffer, 1024, "%s/AppleESCertificates.plist", dir_path);
		file_data =  SecOTACopyFileContents(buffer);
	}
	
	if (NULL != file_data)
	{
		CFPropertyListFormat propFormat;
		CFDictionaryRef certsDictionary =  CFPropertyListCreateWithData(kCFAllocatorDefault, file_data, 0, &propFormat, NULL);		
		if (NULL != certsDictionary && CFDictionaryGetTypeID() == CFGetTypeID((CFTypeRef)certsDictionary))
		{	
			CFArrayRef certs = (CFArrayRef)CFDictionaryGetValue(certsDictionary, CFSTR("ProductionEscrowKey"));
			if (NULL != certs && CFArrayGetTypeID() == CFGetTypeID((CFTypeRef)certs) && CFArrayGetCount(certs) > 0)
			{
				result = CFArrayCreateCopy(kCFAllocatorDefault, certs);
			}
			CFRelease(certsDictionary);
		}
		CFRelease(file_data);
	}
	
	return result;
}


static SecOTAPKIRef SecOTACreate()
{
	
	SecOTAPKIRef otapkiref = NULL;

    otapkiref = CFTypeAllocate(SecOTAPKI, struct _OpaqueSecOTAPKI , kCFAllocatorDefault);

	if (NULL == otapkiref)
	{
		return otapkiref;
	}
	
	// Mkae suer that if this routine has to bail that the clean up 
	// will do the right thing
	otapkiref->_blackListSet = NULL;
	otapkiref->_grayListSet = NULL;
	otapkiref->_escrowCertificates = NULL;
	otapkiref->_evPolicyToAnchorMapping = NULL;
	otapkiref->_anchorLookupTable = NULL;
	otapkiref->_anchorTable = NULL;
	otapkiref->_assetVersion = 0;
	
	// Start off by getting the correct asset directory info
	int asset_version = 0;
	const char* path_ptr = "/System/Library/Frameworks/Security.framework";
	otapkiref->_assetVersion = asset_version;
	

	
	// Get the set of black listed keys
	CFSetRef blackKeysSet = InitializeBlackList(path_ptr);
	if (NULL == blackKeysSet)
	{
		CFReleaseNull(otapkiref);
		return otapkiref;
	}
	otapkiref->_blackListSet = blackKeysSet;
	
	// Get the set of gray listed keys
	CFSetRef grayKeysSet = InitializeGrayList(path_ptr);
	if (NULL == grayKeysSet)
	{
		CFReleaseNull(otapkiref);
		return otapkiref;
	}
	otapkiref->_grayListSet = grayKeysSet;
	
	CFArrayRef escrowCerts = InitializeEscrowCertificates(path_ptr);
	if (NULL == escrowCerts)
	{
		CFReleaseNull(otapkiref);
		return otapkiref;
	}
	otapkiref->_escrowCertificates = escrowCerts;
	
	// Geht the mapping of EV Policy OIDs to Anchor digest
	CFDictionaryRef evOidToAnchorDigestMap = InitializeEVPolicyToAnchorDigestsTable(path_ptr);
	if (NULL == evOidToAnchorDigestMap)
	{
		CFReleaseNull(otapkiref);
		return otapkiref;
	}
	otapkiref->_evPolicyToAnchorMapping = evOidToAnchorDigestMap;
	
	CFDictionaryRef anchorLookupTable = NULL;
	const char* anchorTablePtr = NULL;
	
	if (!InitializeAnchorTable(path_ptr, &anchorLookupTable, &anchorTablePtr))
	{
		CFReleaseSafe(anchorLookupTable);
		if (NULL != anchorTablePtr)
		{
			free((void *)anchorTablePtr);
		}
		
		CFReleaseNull(otapkiref);
		return otapkiref;
	}
	otapkiref->_anchorLookupTable = anchorLookupTable;
	otapkiref->_anchorTable = anchorTablePtr;
	return otapkiref;		
}

static dispatch_once_t kInitializeOTAPKI = 0;
static const char* kOTAQueueLabel = "com.apple.security.OTAPKIQueue";
static dispatch_queue_t kOTAQueue;
static SecOTAPKIRef kCurrentOTAPKIRef = NULL;

SecOTAPKIRef SecOTAPKICopyCurrentOTAPKIRef()
{
	__block SecOTAPKIRef result = NULL;
	dispatch_once(&kInitializeOTAPKI,
		^{
			kOTAQueue = dispatch_queue_create(kOTAQueueLabel, NULL);
			kCurrentOTAPKIRef = SecOTACreate();
		});

	dispatch_sync(kOTAQueue, 
		^{
			result = kCurrentOTAPKIRef;
			CFRetainSafe(result);
		});
	return result;
}


CFSetRef SecOTAPKICopyBlackListSet(SecOTAPKIRef otapkiRef)
{
	CFSetRef result = NULL;
	if (NULL == otapkiRef)
	{
		return result;
	}
	
	result = otapkiRef->_blackListSet;
	CFRetainSafe(result);
	return result;
}


CFSetRef SecOTAPKICopyGrayList(SecOTAPKIRef otapkiRef)
{
	CFSetRef result = NULL;
	if (NULL == otapkiRef)
	{
		return result;
	}
	
	result = otapkiRef->_grayListSet;
	CFRetainSafe(result);
	return result;
}

CFArrayRef SecOTAPKICopyEscrowCertificates(SecOTAPKIRef otapkiRef)
{
	CFArrayRef result = NULL;
	if (NULL == otapkiRef)
	{
		return result;
	}
	
	result = otapkiRef->_escrowCertificates;
	CFRetainSafe(result);
	return result;
}


CFDictionaryRef SecOTAPKICopyEVPolicyToAnchorMapping(SecOTAPKIRef otapkiRef)
{
	CFDictionaryRef result = NULL;
	if (NULL == otapkiRef)
	{
		return result;
	}
	
	result = otapkiRef->_evPolicyToAnchorMapping;
	CFRetainSafe(result);
	return result;
}


CFDictionaryRef SecOTAPKICopyAnchorLookupTable(SecOTAPKIRef otapkiRef)
{
	CFDictionaryRef result = NULL;
	if (NULL == otapkiRef)
	{
		return result;
	}
	
	result = otapkiRef->_anchorLookupTable;
	CFRetainSafe(result);
	return result;
}

const char*	SecOTAPKIGetAnchorTable(SecOTAPKIRef otapkiRef)
{
	const char* result = NULL;
	if (NULL == otapkiRef)
	{
		return result;
	}
	
	result = otapkiRef->_anchorTable;
	return result;
}

int SecOTAPKIGetAssetVersion(SecOTAPKIRef otapkiRef)
{
	int result = 0;
	if (NULL == otapkiRef)
	{
		return result;
	}
	
	result = otapkiRef->_assetVersion;
	return result;
}

void SecOTAPKIRefreshData()
{
	SecOTAPKIRef new_otaPKRef = SecOTACreate();
	dispatch_sync(kOTAQueue, 
		^{
			CFReleaseSafe(kCurrentOTAPKIRef);
			kCurrentOTAPKIRef = new_otaPKRef;
		});
}

CFArrayRef SecOTAPKICopyCurrentEscrowCertificates(CFErrorRef* error)
{
	CFArrayRef result = NULL;
	
	SecOTAPKIRef otapkiref = SecOTAPKICopyCurrentOTAPKIRef();
	if (NULL == otapkiref)
	{
		return result;
	}
	
	result = SecOTAPKICopyEscrowCertificates(otapkiref);
	CFRelease(otapkiref);
	
	if (NULL == result)
	{
	}
	return result;
}

int SecOTAPKIGetCurrentAssetVersion(CFErrorRef* error)
{
	int result = 0;
	
	SecOTAPKIRef otapkiref = SecOTAPKICopyCurrentOTAPKIRef();
	if (NULL == otapkiref)
	{
		return result;
	}
	
	result = otapkiref->_assetVersion;
	return result;
}

int SecOTAPKISignalNewAsset(CFErrorRef* error)
{
	SecOTAPKIRefreshData();
	return 1;	
}
