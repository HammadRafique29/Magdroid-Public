import { useState } from "react";
import { Cloud, Loader2, Key } from "lucide-react";
import { cn } from "@/lib/utils";
import ButtonGroup from "./ButtonGroup";

interface TunnelControlsProps {
  loading: Record<string, boolean>;
  onApiCall: (endpoint: string, buttonId: string, body?: object) => void;
}

const TunnelControls = ({ loading, onApiCall }: TunnelControlsProps) => {
  const [tunnelToken, setTunnelToken] = useState("");

  const cloudflaredButtons = [
    { id: "start_scrcpy_tunnel", label: "Start ws-scrcpy Tunnel", endpoint: "/start_scrcpy_tunnel" },
    { id: "stop_scrcpy_tunnel", label: "Stop ws-scrcpy Tunnel", endpoint: "/stop_scrcpy_tunnel" },
  ];

  const handleStartNamedTunnel = () => {
    if (tunnelToken) {
      onApiCall("/start_named_tunnel", "start_named_tunnel", { token: tunnelToken });
    }
  };

  return (
    <div className="bg-card rounded-xl border border-border p-5">
      <h3 className="text-lg font-semibold mb-4 text-primary flex items-center gap-2">
        <Cloud className="w-5 h-5" />
        Cloudflared Tunnel Controls
      </h3>
      <div className="space-y-4">
        <ButtonGroup
          buttons={cloudflaredButtons}
          loading={loading}
          onClick={onApiCall}
        />
        
        <div className="border-t border-border pt-4">
          <h4 className="font-medium text-foreground mb-3 flex items-center gap-2">
            <Key className="w-4 h-4 text-muted-foreground" />
            Start with Token (Named Tunnel)
          </h4>
          <input
            type="text"
            value={tunnelToken}
            onChange={(e) => setTunnelToken(e.target.value)}
            placeholder="Paste Cloudflared Tunnel Token"
            className={cn(
              "w-full bg-background border border-border rounded-lg px-4 py-3 mb-3",
              "text-foreground placeholder:text-muted-foreground",
              "focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary",
              "transition-all duration-200"
            )}
          />
          <button
            onClick={handleStartNamedTunnel}
            disabled={!tunnelToken || loading.start_named_tunnel}
            className={cn(
              "w-full bg-primary text-primary-foreground font-semibold py-3 px-4 rounded-lg",
              "transition-all duration-300 flex items-center justify-center gap-2",
              "hover:shadow-glow hover:-translate-y-0.5",
              "disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:translate-y-0 disabled:hover:shadow-none"
            )}
          >
            {loading.start_named_tunnel ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" />
                <span>Starting...</span>
              </>
            ) : (
              "Start Named Tunnel"
            )}
          </button>
        </div>
      </div>
    </div>
  );
};

export default TunnelControls;
