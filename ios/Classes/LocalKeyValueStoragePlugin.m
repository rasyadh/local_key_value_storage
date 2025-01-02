#import "LocalKeyValueStoragePlugin.h"

@implementation LocalKeyValueStoragePlugin

static NSSet<Class> * _compatibleTypes = nil;
+ (NSSet<Class> *) compatibleTypes {
    if (_compatibleTypes == nil) {
        _compatibleTypes = [NSSet setWithObjects:
                [NSString class],
                [NSNumber class],
                [FlutterStandardTypedData class], nil];
    }
    return _compatibleTypes;
}

// https://api.flutter.dev/flutter/services/StandardMessageCodec-class.html
+ (BOOL)isDataFlutterCompatible:(id)data {
    if (data == nil) {
        return true;
    }
    if ([data isKindOfClass:[NSArray class]]) {
        for (id subData in data) {
            if (![LocalKeyValueStoragePlugin isDataFlutterCompatible:subData]) {
                return false;
            }
            return true;
        }
    } else if ([data isKindOfClass:[NSDictionary class]]) {
        for (id subKey in data) {
            if (![LocalKeyValueStoragePlugin isDataFlutterCompatible:subKey] ||
                ![LocalKeyValueStoragePlugin isDataFlutterCompatible:[data objectForKey:subKey]]) {
                return false;
            }
            return true;
        }
    }
    for (Class class in [LocalKeyValueStoragePlugin compatibleTypes]) {
        if ([data isKindOfClass:class]) {
            return true;
        }
    }
    return false;
}

+ (NSDictionary*)filterOutIncompatibleTypes:(NSDictionary*)dictionary {

    NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithDictionary: dictionary];
    for (id key in dictionary) {
        id data = [newDict objectForKey: key];
        if (![LocalKeyValueStoragePlugin isDataFlutterCompatible:key] ||
            ![LocalKeyValueStoragePlugin isDataFlutterCompatible:data]) {
            [newDict removeObjectForKey: key];
        }
    }
    return newDict;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:@"rasyadh/local_key_value_storage"
                                                                binaryMessenger:registrar.messenger];
    [channel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
        NSString *method = [call method];
        NSDictionary *arguments = [call arguments];
        NSString *storageName = arguments[@"storageName"];
        NSUserDefaults *storage;
        if (storageName == nil) {
            storage = [NSUserDefaults standardUserDefaults];
            // standardUserDefaults will use the app bundleIdentifier as the domain
            // https://developer.apple.com/documentation/foundation/nsuserdefaults/1416603-standarduserdefaults
            storageName = [[NSBundle mainBundle] bundleIdentifier];
        } else {
            storage = [[NSUserDefaults alloc] initWithSuiteName:storageName];
        }

        if ([method isEqualToString:@"getAll"]) {
            NSDictionary *allDictionary = [storage persistentDomainForName:storageName];
            // filter out incompatible types.
            // We don't know yet how it can happen, but it happens
            NSDictionary *cleanDictionary = [LocalKeyValueStoragePlugin filterOutIncompatibleTypes:allDictionary];
            result(cleanDictionary);
        } else if ([method isEqualToString:@"setBool"]) {
            NSString *key = arguments[@"key"];
            NSNumber *value = arguments[@"value"];
            [storage setBool:value.boolValue forKey:key];
            result(@YES);
        } else if ([method isEqualToString:@"setInt"]) {
            NSString *key = arguments[@"key"];
            NSNumber *value = arguments[@"value"];
            // int type in Dart can come to native side in a variety of forms
            // It is best to store it as is and send it back when needed.
            // Platform channel will handle the conversion.
            [storage setValue:value forKey:key];
            result(@YES);
        } else if ([method isEqualToString:@"setDouble"]) {
            NSString *key = arguments[@"key"];
            NSNumber *value = arguments[@"value"];
            [storage setDouble:value.doubleValue forKey:key];
            result(@YES);
        } else if ([method isEqualToString:@"setString"]) {
            NSString *key = arguments[@"key"];
            NSString *value = arguments[@"value"];
            [storage setValue:value forKey:key];
            result(@YES);
        } else if ([method isEqualToString:@"setStringList"]) {
            NSString *key = arguments[@"key"];
            NSArray *value = arguments[@"value"];
            [storage setValue:value forKey:key];
            result(@YES);
        } else if ([method isEqualToString:@"commit"]) {
            // synchronize is deprecated.
            // "this method is unnecessary and shouldn't be used."
            result(@YES);
        } else if ([method isEqualToString:@"remove"]) {
            [storage removeObjectForKey:arguments[@"key"]];
            result(@YES);
        } else if ([method isEqualToString:@"clear"]) {
            NSDictionary *allDictionary = [storage persistentDomainForName:storageName];
            for (NSString *key in allDictionary) {
                [storage removeObjectForKey:key];
            }
            result(@YES);
        } else {
            result(FlutterMethodNotImplemented);
        }
    }];
}

@end
