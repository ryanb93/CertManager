/*
 * Copyright (c) 2006-2010 Apple Inc. All Rights Reserved.
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
 * SecTrustServer.c - certificate trust evaluation engine
 *
 *  Created by Michael Brouwer on 12/12/08.
 *
 */
#include <Securityd/OTATrustUtilities.h>
#include <Securityd/SecTrustServer.h>
#include <Securityd/SecCertificate.h>
#include <CoreFoundation/CFNumber.h>
#include <CoreFoundation/CFArray.h>

 CFArrayRef CopyCertDataFromIndices(CFArrayRef offsets)
{
    CFMutableArrayRef result = NULL;
    
    SecOTAPKIRef otapkiref = SecOTAPKICopyCurrentOTAPKIRef();
    if (NULL == otapkiref)
    {
        return result;
    }
    
    const char* anchorTable = SecOTAPKIGetAnchorTable(otapkiref);
    if (NULL == anchorTable)
    {
        CFRelease(otapkiref);
        return result;
    }
    
    CFIndex num_offsets = CFArrayGetCount(offsets);
    
    result = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    
    for (CFIndex idx = 0; idx < num_offsets; idx++)
    {
        CFNumberRef offset = (CFNumberRef)CFArrayGetValueAtIndex(offsets, idx);
        uint32_t offset_value = 0;
        if (CFNumberGetValue(offset, kCFNumberSInt32Type, &offset_value))
        {
            char* pDataPtr = (char *)(anchorTable + offset_value);
            //int32_t record_length = *((int32_t * )pDataPtr);
            //record_length = record_length;
            pDataPtr += sizeof(uint32_t);
            
            int32_t cert_data_length = *((int32_t * )pDataPtr);
            pDataPtr += sizeof(uint32_t);
            
            CFDataRef cert_data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, (const UInt8 *)pDataPtr,
                                                              cert_data_length, kCFAllocatorNull);
            if (NULL != cert_data)
            {
                CFArrayAppendValue(result, cert_data);
                CFRelease(cert_data);
            }
        }
    }
    CFRelease(otapkiref);
    return result;
}

 CFArrayRef CopyCertsFromIndices(CFArrayRef offsets)
{
    CFMutableArrayRef result = NULL;
    
    CFArrayRef cert_data_array = CopyCertDataFromIndices(offsets);
    
    if (NULL != cert_data_array)
    {
        result = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
        CFIndex num_cert_datas = CFArrayGetCount(cert_data_array);
        for (CFIndex idx = 0; idx < num_cert_datas; idx++)
        {
            CFDataRef cert_data = (CFDataRef)CFArrayGetValueAtIndex(cert_data_array, idx);
            if (NULL != cert_data)
            {
                SecCertificateRef cert = SecCertificateCreateWithData(kCFAllocatorDefault, cert_data);
                if (NULL != cert)
                {
                    CFArrayAppendValue(result, cert);
                    CFRelease(cert);
                }
            }
        }
        CFRelease(cert_data_array);
    }
    return result;
    
}