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
#include <Securityd/SecCFWrappers.h>
#include <Securityd/SecBasePriv.h>
#include <dispatch/dispatch.h>
#include <CommonCrypto/CommonDigest.h>

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
    CFReleaseNull(otapkiref->_anchorLookupTable);
	free((void *)otapkiref->_anchorTable);
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