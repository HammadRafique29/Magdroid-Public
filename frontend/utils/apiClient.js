import axios from 'axios';

// Create axios instance
const apiClient = axios.create({
  baseURL: process.env.NEXT_PUBLIC_BACKEND_API_URL,
  timeout: 60000, // Increased timeout for long-running operations
});

// Function to get the Clerk token
let getClerkToken;

// Setter for the token function
export const setTokenProvider = (tokenProvider) => {
  getClerkToken = tokenProvider;
};

// Add a request interceptor to include the auth token
apiClient.interceptors.request.use(
  async (config) => {
    if (getClerkToken) {
      const token = await getClerkToken();
      if (token) {
        config.headers['Authorization'] = `Bearer ${token}`;
      }
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Add a response interceptor to handle data and errors
apiClient.interceptors.response.use(
  (response) => {
    // Return the response data directly
    return response.data;
  },
  (error) => {
    // Handle errors globally
    let errorMessage = 'An unexpected error occurred.';
    if (error.response) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx
      errorMessage = error.response.data.message || error.response.data.details || `Error: ${error.response.status}`;
    } else if (error.request) {
      // The request was made but no response was received
      errorMessage = 'No response from server. Please check your network connection.';
    } else {
      // Something happened in setting up the request that triggered an Error
      errorMessage = error.message;
    }
    // Return a rejected promise with a standardized error object
    return Promise.reject({
      status: 'error',
      message: errorMessage,
      details: error.response?.data?.details || '',
    });
  }
);

export default apiClient;