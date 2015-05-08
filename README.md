CertManager
===========

CertManager is an application and tweak for jailbroken iOS devices that allows users to define the certificates they trust on their devices.

By default, all root certificate authorities are trusted and there is no way for users to decide which ones they want to trust. On other platforms this is a feature that is built into the OS and available to use but as iOS lacks any sort of keychain management system this is not available.

The project can be built and installed using the theos build tool by running:

```
make package install
```

This will build the front-end application 'CertManager' and also the Cydia Substrate tweak 'CertHook' and bundle them together into an installable .deb file.

You will find that it will not build without the correct headers, so will need to go into the theos folder and 'git pull' my custom theos build which includes the necessary dependencies.

Alternatively you can download the pre-compiled debian file and install that on your device manually, hopefully this application will soon be in Cydia so you will also be able to install it directly from your device.