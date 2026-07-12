// Non-web fallback: the OS handles app installation, so these are inert.
bool canInstall() => false;
bool isStandalone() => false;
bool isIosSafari() => false;
Future<String> promptInstall() async => 'unavailable';
void setAppName(String name) {}
