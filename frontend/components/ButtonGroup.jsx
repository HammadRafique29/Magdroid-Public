const ButtonGroup = ({ title, buttons, loading, onClick }) => {
    return (
      <div className="bg-gray-800 p-6 rounded-lg shadow-lg">
        <h3 className="text-xl font-semibold mb-4 text-indigo-400">{title}</h3>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {buttons.map((button) => (
            <button
              key={button.id}
              onClick={() => onClick(button.endpoint, button.id)}
              disabled={loading[button.id]}
              className="bg-indigo-500 hover:bg-indigo-600 text-white font-bold py-3 px-4 rounded transition-colors duration-300 disabled:bg-gray-600 disabled:cursor-not-allowed flex items-center justify-center"
            >
              {loading[button.id] ? (
                <span className="flex items-center">
                  <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  Running...
                </span>
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