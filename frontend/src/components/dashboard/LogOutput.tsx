import { Terminal } from "lucide-react";

interface LogOutputProps {
  log: string;
}

const LogOutput = ({ log }: LogOutputProps) => {
  return (
    <div className="bg-card rounded-xl border border-border p-5 h-96 flex flex-col">
      <h3 className="text-lg font-semibold mb-4 text-primary flex items-center gap-2">
        <Terminal className="w-5 h-5" />
        Logs
      </h3>
      <div className="flex-1 bg-background rounded-lg border border-border overflow-hidden">
        <pre className="h-full overflow-auto p-4 text-sm text-foreground font-mono whitespace-pre-wrap break-words scrollbar-thin">
          {log || <span className="text-muted-foreground">No logs yet...</span>}
        </pre>
      </div>
    </div>
  );
};

export default LogOutput;
