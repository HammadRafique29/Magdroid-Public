import { useState } from "react";
import { Smartphone, Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";

interface DeviceConnectorProps {
  onConnect: (deviceId: string) => void;
  loading: boolean;
}

const DeviceConnector = ({ onConnect, loading }: DeviceConnectorProps) => {
  const [deviceId, setDeviceId] = useState("");

  const handleConnect = () => {
    if (deviceId) {
      onConnect(deviceId);
    }
  };

  return (
    <div className="bg-card rounded-xl border border-border p-5">
      <h3 className="text-lg font-semibold mb-4 text-primary flex items-center gap-2">
        <Smartphone className="w-5 h-5" />
        Connect a Device
      </h3>
      <div className="space-y-3">
        <input
          type="text"
          value={deviceId}
          onChange={(e) => setDeviceId(e.target.value)}
          placeholder="Enter device-id (e.g., 192.168.1.100)"
          className={cn(
            "w-full bg-background border border-border rounded-lg px-4 py-3",
            "text-foreground placeholder:text-muted-foreground",
            "focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary",
            "transition-all duration-200 input-glow"
          )}
        />
        <button
          onClick={handleConnect}
          disabled={!deviceId || loading}
          className={cn(
            "w-full bg-primary text-primary-foreground font-semibold py-3 px-4 rounded-lg",
            "transition-all duration-300 flex items-center justify-center gap-2",
            "hover:shadow-glow hover:-translate-y-0.5",
            "disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:translate-y-0 disabled:hover:shadow-none"
          )}
        >
          {loading ? (
            <>
              <Loader2 className="w-4 h-4 animate-spin" />
              <span>Connecting...</span>
            </>
          ) : (
            "Connect"
          )}
        </button>
      </div>
    </div>
  );
};

export default DeviceConnector;
