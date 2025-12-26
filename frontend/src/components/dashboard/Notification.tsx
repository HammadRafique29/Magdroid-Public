import { useEffect, useState } from "react";
import { X, CheckCircle, AlertCircle, Info } from "lucide-react";
import { cn } from "@/lib/utils";

interface NotificationProps {
  message: string;
  type: "success" | "error" | "info" | "";
  onClose: () => void;
}

const Notification = ({ message, type, onClose }: NotificationProps) => {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (message) {
      setVisible(true);
      const timer = setTimeout(() => {
        handleClose();
      }, 5000);
      return () => clearTimeout(timer);
    }
  }, [message]);

  const handleClose = () => {
    setVisible(false);
    if (onClose) {
      onClose();
    }
  };

  if (!visible || !message) {
    return null;
  }

  const icons = {
    success: CheckCircle,
    error: AlertCircle,
    info: Info,
    "": Info,
  };

  const Icon = icons[type] || Info;

  return (
    <div
      className={cn(
        "fixed top-5 right-5 p-4 rounded-xl shadow-lg max-w-sm z-50",
        "transform transition-all duration-300 animate-slide-in-left",
        "border backdrop-blur-sm",
        type === "success" && "bg-emerald-500/90 border-emerald-400/50 text-foreground",
        type === "error" && "bg-destructive/90 border-destructive/50 text-foreground",
        (type === "info" || type === "") && "bg-primary/90 border-primary/50 text-primary-foreground"
      )}
    >
      <div className="flex items-start gap-3">
        <Icon className="w-5 h-5 flex-shrink-0 mt-0.5" />
        <p className="flex-1 text-sm font-medium">{message}</p>
        <button
          onClick={handleClose}
          className="p-1 hover:bg-foreground/10 rounded transition-colors"
        >
          <X className="w-4 h-4" />
        </button>
      </div>
    </div>
  );
};

export default Notification;
