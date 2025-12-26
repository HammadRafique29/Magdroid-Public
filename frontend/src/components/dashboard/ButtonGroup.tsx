import { Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";

interface Button {
  id: string;
  label: string;
  endpoint: string;
}

interface ButtonGroupProps {
  title?: string;
  buttons: Button[];
  loading: Record<string, boolean>;
  onClick: (endpoint: string, buttonId: string) => void;
}

const ButtonGroup = ({ title, buttons, loading, onClick }: ButtonGroupProps) => {
  return (
    <div className="bg-card rounded-xl border border-border p-5">
      {title && (
        <h3 className="text-lg font-semibold mb-4 text-primary flex items-center gap-2">
          <div className="w-2 h-2 rounded-full bg-primary animate-pulse-glow" />
          {title}
        </h3>
      )}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        {buttons.map((button) => (
          <button
            key={button.id}
            onClick={() => onClick(button.endpoint, button.id)}
            disabled={loading[button.id]}
            className={cn(
              "relative bg-primary text-primary-foreground font-semibold py-3 px-4 rounded-lg",
              "transition-all duration-300 flex items-center justify-center gap-2",
              "hover:shadow-glow hover:-translate-y-0.5",
              "disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:translate-y-0 disabled:hover:shadow-none",
              "focus:outline-none focus:ring-2 focus:ring-primary/50 focus:ring-offset-2 focus:ring-offset-background"
            )}
          >
            {loading[button.id] ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" />
                <span>Running...</span>
              </>
            ) : (
              button.label
            )}
          </button>
        ))}
      </div>
    </div>
  );
};

export default ButtonGroup;
