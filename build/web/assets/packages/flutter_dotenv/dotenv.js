/**
 * Mock implementation of the flutter_dotenv package for web
 */
window.flutter_dotenv = {
  get: function(key) {
    console.log('flutter_dotenv.get called with key:', key);
    return window[key] || null;
  },
  env: {
    SUPABASE_URL: "https://hvxgdyxqmkpmhejpumlc.supabase.co",
    SUPABASE_ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh2eGdkeXhxbWtwbWhlanB1bWxjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ0Nzk2OTMsImV4cCI6MjA2MDA1NTY5M30.JfS42uMEMgqNiKKfF17OKjMa6QRq6LUaJkESdAdLmdA",
    OPENROUTESERVICE_API_KEY: "5b3ce3597851110001cf6248c39073c1932f417f9d57d67334af0a15",
    OPENROUTE_API_KEY: "5b3ce3597851110001cf6248c39073c1932f417f9d57d67334af0a15"
  }
}; 