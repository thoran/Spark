/*
 *  AEScript.c
 *  SparkServer
 *
 *  Created by Black Moon Team.
 *  Copyright (c) 2004 - 2006 Shadow Lab. All rights reserved.
 */

#include "SDAEHandlers.h"

#include <SparkKit/SparkKit.h>

#include <ShadowKit/SKAEFunctions.h>
#include <ShadowKit/SKProcessFunctions.h>

OSStatus SDGetEditorIsTrapping(Boolean *trapping) {
  check(trapping);
  *trapping = FALSE;
  ProcessSerialNumber psn;
  OSStatus err = GetFrontProcess(&psn);
  require_noerr(err, bail);
  
  /* Check front process */
  ProcessInfoRec info;
  info.processInfoLength = sizeof(info);
  info.processName = NULL;
  info.processAppSpec = NULL;
  err = GetProcessInformation(&psn, &info);
  require_noerr(err, bail);
  
  /* If Spark Editor is the front process, send apple event */
  if (kSparkEditorHFSCreatorType == info.processSignature) {
    AEDesc reply = SKAEEmptyDesc();
    AEDesc theEvent = SKAEEmptyDesc();
    
    err = SKAECreateEventWithTargetProcess(&psn, kAECoreSuite, kAEGetData, &theEvent);
    require_noerr(err, bail);
    
    err = SKAEAddPropertyObjectSpecifier(&theEvent, keyDirectObject, typeProperty, kSparkEditorIsTrapping, NULL);
    require_noerr(err, fevent);
    
    err = SKAEAddMagnitude(&theEvent);
    require_noerr(err, fevent);

    /* Timeout: 500 ms ?? */
    err = SKAESendEvent(&theEvent, kAEWaitReply, 500, &reply);
    require_noerr(err, fevent);
    
    err = SKAEGetBooleanFromAppleEvent(&reply, keyDirectObject, trapping);
    /* Release Apple event descriptor */
fevent:
      SKAEDisposeDesc(&theEvent);
    SKAEDisposeDesc(&reply);
  }
  
bail:
  return err;
}
