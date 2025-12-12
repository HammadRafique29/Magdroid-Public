import { SignedIn, SignedOut, SignIn, useUser } from "@clerk/nextjs";
import Dashboard from "./dashboard";

const IndexPage = () => {
  const { isLoaded, user } = useUser();

  if (!isLoaded) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-gray-900 text-white">
        <p>Loading Clerk...</p>
      </div>
    );
  }

  return (
    <>
      <SignedIn>
        {/* If the user is signed in, display the Dashboard */}
        <Dashboard />
      </SignedIn>
      <SignedOut>
        {/* If the user is signed out, display the Sign In component */}
        <div className="flex items-center justify-center min-h-screen bg-gray-900">
          <SignIn 
            routing="path" 
            path="/" 
            signUpUrl="/sign-up"
            appearance={{
              variables: {
                colorPrimary: '#6366f1',
                colorBackground: '#1f2937', // bg-gray-800
                colorText: 'white',
                colorInputBackground: '#374151', // bg-gray-700
                colorInputText: 'white',
              },
            }}
          />
        </div>
      </SignedOut>
    </>
  );
};

export default IndexPage;