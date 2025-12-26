import { Globe, ExternalLink } from "lucide-react";

interface TunnelUrlProps {
  publicUrl: string;
}

const TunnelUrl = ({ publicUrl }: TunnelUrlProps) => {
  return (
    <div className="bg-card rounded-xl border border-border p-5">
      <h3 className="text-lg font-semibold mb-4 text-primary flex items-center gap-2">
        <Globe className="w-5 h-5" />
        Tunnel URL
      </h3>
      <div className="bg-background rounded-lg border border-border p-4">
        {publicUrl ? (
          <a
            href={publicUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="text-primary hover:underline flex items-center gap-2 group"
          >
            <span className="truncate">{publicUrl}</span>
            <ExternalLink className="w-4 h-4 flex-shrink-0 opacity-0 group-hover:opacity-100 transition-opacity" />
          </a>
        ) : (
          <p className="text-muted-foreground text-sm">Tunnel is not active.</p>
        )}
      </div>
    </div>
  );
};

export default TunnelUrl;
