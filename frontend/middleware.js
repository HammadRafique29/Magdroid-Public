import { authMiddleware } from '@clerk/nextjs';

export default authMiddleware({
  publicRoutes: ['/', '/dashboard', '/sign-up', '/sso-callback'],
  ignoredRoutes: ['/api/:path*', '/get_adb_devices', '/assign_tcpip', '/get_mdns_services', '/connect_ip_devices'],
});

export const config = {
  matcher: ['/((?!.*\\..*|_next).*)', '/', '/(api|trpc)(.*)'],
};