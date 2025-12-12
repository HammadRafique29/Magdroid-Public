import { SignUp } from '@clerk/nextjs';

export default function SignUpPage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <SignUp 
          appearance={{
            elements: {
              card: 'shadow-xl rounded-2xl',
              headerTitle: 'text-3xl font-bold text-gray-800',
              headerSubtitle: 'text-gray-600',
              socialButtonsBlockButton: 'border border-gray-300 rounded-lg',
              formFieldInput: 'w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent',
              formButtonPrimary: 'w-full bg-indigo-600 text-white py-3 rounded-lg font-medium hover:bg-indigo-700 transition duration-200',
              footerActionLink: 'text-indigo-600 hover:text-indigo-800'
            }
          }}
          routing="path"
          path="/sign-up"
          signInUrl="/"
        />
      </div>
    </div>
  );
}