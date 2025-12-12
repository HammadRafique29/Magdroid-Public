import { useState, useEffect } from 'react';
import { useAuth, useClerk } from '@clerk/nextjs';
import { useRouter } from 'next/router';
import apiClient, { setTokenProvider } from '../utils/apiClient';

import ButtonGroup from '../components/ButtonGroup';
import LogOutput from '../components/LogOutput';
import Notification from '../components/Notification';

const Dashboard = () => {
    const { isLoaded, isSignedIn, getToken } = useAuth();
    const { signOut } = useClerk();
    const router = useRouter();

    const [log, setLog] = useState('');
    const [loading, setLoading] = useState({});
    const [deviceId, setDeviceId] = useState('');
    const [publicUrl, setPublicUrl] = useState('');
    const [notification, setNotification] = useState({ message: '', type: '' });
    const [tunnelToken, setTunnelToken] = useState('');

    // Set the token provider for the API client
    useEffect(() => {
        if (isLoaded && isSignedIn) {
            setTokenProvider(getToken);
        }
    }, [isLoaded, isSignedIn, getToken]);

    // Redirect if not signed in
    useEffect(() => {
        if (isLoaded && !isSignedIn) {
            router.push('/login');
        }
    }, [isLoaded, isSignedIn, router]);

    const handleApiCall = async (endpoint, buttonId, body = null) => {
        setLoading((prev) => ({ ...prev, [buttonId]: true }));
        setLog(`[${new Date().toLocaleTimeString()}] Starting ${buttonId}...`);

        try {
            const response = body
                ? await apiClient.post(endpoint, body)
                : await apiClient.get(endpoint);
            
            // Determine the primary log content.
            let logMessage = '';
            if (response && response.output) {
                logMessage = typeof response.output === 'string'
                    ? response.output
                    : JSON.stringify(response.output, null, 2);
            } else {
                // Fallback for responses without an 'output' field
                logMessage = JSON.stringify(response, null, 2);
            }

            // Replace the log with the new output
            setLog(logMessage);
            setNotification({ message: response.message || `${buttonId} completed successfully!`, type: 'success' });

            // Handle the public_url, including clearing it if it's null.
            if (response.public_url) {
                setPublicUrl(response.public_url);
            } else if (response.public_url === null) {
                setPublicUrl('');
            }
        } catch (error) {
            const errorMessage = error.message || 'An unknown error occurred.';
            // Show only the current error
            setLog(`Error: ${errorMessage}`);
            setNotification({ message: `Error during ${buttonId}: ${errorMessage}`, type: 'error' });
        } finally {
            setLoading((prev) => ({ ...prev, [buttonId]: false }));
            // Optionally, you can add a "Finished" message, but it will be replaced on the next click.
            // setLog((prev) => `${prev}\n[${new Date().toLocaleTimeString()}] Finished ${buttonId}.`);
        }
    };

    const adbButtons = [
        { id: 'get_adb_devices', label: 'Get ADB Devices', endpoint: '/get_adb_devices' },
        { id: 'get_mdns_services', label: 'Get mDNS Services', endpoint: '/get_mdns_services' },
        { id: 'assign_tcpip', label: 'Assign TCP/IP', endpoint: '/assign_tcpip' },
        { id: 'connect_ip_devices', label: 'Connect All IP Devices', endpoint: '/connect_ip_devices' },
        { id: 'disconnect_all_devices', label: 'Disconnect All Devices', endpoint: '/disconnect_all_devices' },
    ];

    const wsScrcpyButtons = [
        { id: 'run_ws_scrcpy', label: 'Run ws-scrcpy', endpoint: '/run_ws_scrcpy' },
        { id: 'stop_ws_scrcpy', label: 'Stop ws-scrcpy', endpoint: '/stop_ws_scrcpy' },
    ];

    const cloudflaredButtons = [
        { id: 'start_scrcpy_tunnel', label: 'Start ws-scrcpy Tunnel', endpoint: '/start_scrcpy_tunnel' },
        { id: 'stop_scrcpy_tunnel', label: 'Stop ws-scrcpy Tunnel', endpoint: '/stop_scrcpy_tunnel' },
    ];

    if (!isLoaded || !isSignedIn) {
        return (
            <div className="flex items-center justify-center min-h-screen bg-gray-900 text-white">
                <p>Loading...</p>
            </div>
        );
    }

    return (
        <div className="min-h-screen bg-gray-900 text-gray-200">
            <Notification
                message={notification.message}
                type={notification.type}
                onClose={() => setNotification({ message: '', type: '' })}
            />
            <header className="bg-gray-800 p-4 shadow-md">
                <div className="container mx-auto flex justify-between items-center">
                    <h1 className="text-2xl font-bold text-indigo-400">Magdroid Dashboard</h1>
                    <button
                        onClick={() => signOut({ redirectUrl: '/' })}
                        className="bg-red-500 hover:bg-red-600 text-white font-bold py-2 px-4 rounded"
                    >
                        Sign Out
                    </button>
                </div>
            </header>

            <main className="container mx-auto p-4 md:p-8">
                <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
                    {/* Controls Column */}
                    <div className="md:col-span-1 space-y-8">
                        <ButtonGroup title="ADB & Device Controls" buttons={adbButtons} loading={loading} onClick={handleApiCall} />

                        <div className="bg-gray-800 p-6 rounded-lg shadow-lg">
                            <h3 className="text-xl font-semibold mb-4 text-indigo-400">Connect a Device</h3>
                            <div className="flex flex-col space-y-4">
                                <input
                                    type="text"
                                    value={deviceId}
                                    onChange={(e) => setDeviceId(e.target.value)}
                                    placeholder="Enter device-id (e.g., 192.168.1.100)"
                                    className="bg-gray-700 border border-gray-600 rounded px-3 py-2 text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                                />
                                <button
                                    onClick={() => handleApiCall(`/connect_device/${deviceId}`, 'connect_device')}
                                    disabled={!deviceId || loading.connect_device}
                                    className="bg-indigo-500 hover:bg-indigo-600 text-white font-bold py-2 px-4 rounded disabled:bg-gray-600 disabled:cursor-not-allowed"
                                >
                                    {loading.connect_device ? 'Connecting...' : 'Connect'}
                                </button>
                            </div>
                        </div>

                        <ButtonGroup title="ws-scrcpy Controls" buttons={wsScrcpyButtons} loading={loading} onClick={handleApiCall} />
                        
                        <div className="bg-gray-800 p-6 rounded-lg shadow-lg">
                            <h3 className="text-xl font-semibold mb-4 text-indigo-400">Cloudflared Tunnel Controls</h3>
                            <div className="space-y-4">
                                <ButtonGroup buttons={cloudflaredButtons} loading={loading} onClick={handleApiCall} />
                                <div className="border-t border-gray-700 pt-4">
                                    <h4 className="font-semibold mb-2">Start with Token (Named Tunnel)</h4>
                                    <input
                                        type="text"
                                        value={tunnelToken}
                                        onChange={(e) => setTunnelToken(e.target.value)}
                                        placeholder="Paste Cloudflared Tunnel Token"
                                        className="w-full bg-gray-700 border border-gray-600 rounded px-3 py-2 text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 mb-2"
                                    />
                                    <button
                                        onClick={() => handleApiCall('/start_named_tunnel', 'start_named_tunnel', { token: tunnelToken })}
                                        disabled={!tunnelToken || loading.start_named_tunnel}
                                        className="w-full bg-teal-500 hover:bg-teal-600 text-white font-bold py-2 px-4 rounded disabled:bg-gray-600 disabled:cursor-not-allowed"
                                    >
                                        {loading.start_named_tunnel ? 'Starting...' : 'Start Named Tunnel'}
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Log and URL Column */}
                    <div className="md:col-span-2 space-y-8">
                        <div className="bg-gray-800 p-6 rounded-lg shadow-lg">
                            <h3 className="text-xl font-semibold mb-4 text-indigo-400">Tunnel URL</h3>
                            <div className="bg-gray-700 p-4 rounded">
                                {publicUrl ? (
                                    <a href={publicUrl} target="_blank" rel="noopener noreferrer" className="text-green-400 hover:underline">
                                        {publicUrl}
                                    </a>
                                ) : (
                                    <p className="text-gray-400">Tunnel is not active.</p>
                                )}
                            </div>
                        </div>
                        <LogOutput log={log} />
                    </div>
                </div>
            </main>
        </div>
    );
};

export default Dashboard;