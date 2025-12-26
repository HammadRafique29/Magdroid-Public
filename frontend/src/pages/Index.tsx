import { useState } from "react";
import { Zap, Terminal, ExternalLink } from "lucide-react";
import ButtonGroup from "@/components/dashboard/ButtonGroup";
import LogOutput from "@/components/dashboard/LogOutput";
import Notification from "@/components/dashboard/Notification";
import TunnelUrl from "@/components/dashboard/TunnelUrl";
import DeviceConnector from "@/components/dashboard/DeviceConnector";
import TunnelControls from "@/components/dashboard/TunnelControls";

const Index = () => {
  const [log, setLog] = useState("");
  const [loading, setLoading] = useState<Record<string, boolean>>({});
  const [publicUrl, setPublicUrl] = useState("");
  const [notification, setNotification] = useState({ message: "", type: "" as "success" | "error" | "info" | "" });

  const handleApiCall = async (endpoint: string, buttonId: string, body: object | null = null) => {
    setLoading((prev) => ({ ...prev, [buttonId]: true }));
    setLog(`[${new Date().toLocaleTimeString()}] Starting ${buttonId}...`);

    const apiUrl = `${import.meta.env.VITE_BACKEND_API_URL}${endpoint}`;
    console.log(`Fetching: ${apiUrl}`, body);

    try {
      const response = await fetch(apiUrl, {
        method: body ? 'POST' : 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
        body: body ? JSON.stringify(body) : undefined,
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();

      // Format log output based on response structure
      const timestamp = new Date().toLocaleTimeString();
      let logEntry = `[${timestamp}] ${buttonId}: ${data.status.toUpperCase()}\n`;

      if (data.output) {
        logEntry += `\n${data.output}`;
      }

      if (data.details) {
        // logEntry += `\n[${timestamp}] ${data.details}`;
      }

      setLog(`${logEntry}`);

      setNotification({
        message: data.status === "success"
          ? `${buttonId} completed successfully!`
          : data.details || "Operation failed",
        type: data.status === "success" ? "success" : "error"
      });

      if (data.public_url) {
        setPublicUrl(data.public_url);
      } else if (buttonId.includes("stop_tunnel")) {
        setPublicUrl("");
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : "An unknown error occurred.";
      const timestamp = new Date().toLocaleTimeString();
      setLog(`[${timestamp}] ERROR: ${errorMessage}`);
      setNotification({ message: `Error during ${buttonId}: ${errorMessage}`, type: "error" });
    } finally {
      setLoading((prev) => ({ ...prev, [buttonId]: false }));
    }
  };

  const adbButtons = [
    { id: "get_adb_devices", label: "Get ADB Devices", endpoint: "/get_adb_devices" },
    { id: "get_mdns_services", label: "Get mDNS Services", endpoint: "/get_mdns_services" },
    { id: "assign_tcpip", label: "Assign TCP/IP", endpoint: "/assign_tcpip" },
    { id: "connect_ip_devices", label: "Connect All IP Devices", endpoint: "/connect_ip_devices" },
    { id: "disconnect_all_devices", label: "Disconnect All Devices", endpoint: "/disconnect_all_devices" },
  ];

  const handleDeviceConnect = (deviceId: string) => {
    handleApiCall(`/connect_device/${deviceId}`, "connect_device");
  };

  return (
    <div className="min-h-screen bg-background">
      <Notification
        message={notification.message}
        type={notification.type}
        onClose={() => setNotification({ message: "", type: "" })}
      />

      {/* Branding Header */}
      <header className="border-b border-border bg-card/30 backdrop-blur-sm">
        <div className="max-w-7xl mx-auto px-6 py-5">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center border border-primary/20">
              <Zap className="w-7 h-7 text-primary" />
            </div>
            <div>
              <h1 className="text-3xl font-bold text-gradient tracking-tight">MagDroid</h1>
              <p className="text-sm text-muted-foreground">Android Device Automation Dashboard</p>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto p-6">
        <div className="grid grid-cols-1 xl:grid-cols-12 gap-6">
          {/* Left Column - Controls */}
          <div className="xl:col-span-5 space-y-6">
            <div className="animate-fade-in" style={{ animationDelay: "0ms" }}>
              <ButtonGroup
                title="ADB & Device Controls"
                buttons={adbButtons}
                loading={loading}
                onClick={handleApiCall}
              />
            </div>

            <div className="animate-fade-in" style={{ animationDelay: "100ms" }}>
              <DeviceConnector
                onConnect={handleDeviceConnect}
                loading={loading.connect_device || false}
              />
            </div>

            <div className="animate-fade-in" style={{ animationDelay: "200ms" }}>
              <TunnelControls
                loading={loading}
                onApiCall={handleApiCall}
              />
            </div>

            <div className="animate-fade-in" style={{ animationDelay: "250ms" }}>
              <TunnelUrl publicUrl={publicUrl} />
            </div>
          </div>

          {/* Right Column - Logs */}
          <div className="xl:col-span-7">
            <div className="animate-fade-in h-full" style={{ animationDelay: "150ms" }}>
              <LogOutput log={log} />
            </div>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-border bg-card/20 mt-auto">
        <div className="max-w-7xl mx-auto px-6 py-4">
          <p className="text-xs text-muted-foreground text-center">
            MagDroid v1.0 — Android Device Automation
          </p>
        </div>
      </footer>
    </div>
  );
};

export default Index;
