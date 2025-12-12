import { useRef, useEffect } from 'react';

const LogOutput = ({ log }) => {
  const logEndRef = useRef(null);


  return (
    <div className="bg-gray-800 p-6 rounded-lg shadow-lg h-96 flex flex-col">
      <h3 className="text-xl font-semibold mb-4 text-indigo-400">Logs</h3>
      <pre className="flex-grow bg-gray-900 text-white p-4 rounded-md overflow-auto whitespace-pre-wrap break-words text-sm">
        {log}
        <div ref={logEndRef} />
      </pre>
    </div>
  );
};

export default LogOutput;