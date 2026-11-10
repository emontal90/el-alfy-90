// Conditional import: uses the IO version on native platforms,
// and a no-op stub on web.
export 'platform_init_stub.dart'
    if (dart.library.io) 'platform_init_io.dart';

