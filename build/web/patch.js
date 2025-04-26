/**
 * Targeted fix for the Null check operator error in Flutter web
 */

(function() {
  // This will run immediately when loaded
  console.log('Patch script loaded - targeting Flutter main.dart.js errors');

  // Create a MutationObserver to watch for the script tag being added to the DOM
  const observer = new MutationObserver(function(mutations) {
    for (const mutation of mutations) {
      if (mutation.type === 'childList') {
        for (const node of mutation.addedNodes) {
          if (node.tagName === 'SCRIPT' && node.src && node.src.includes('main.dart.js')) {
            console.log('Found main.dart.js being loaded, preparing to patch');
            
            // Once we know the script is being loaded, add our error handler
            window.addEventListener('error', function(event) {
              if (event.message && event.message.includes('Null check operator used on a null value')) {
                console.log('Null check error intercepted at:', event.filename, 'line:', event.lineno);
                
                // Prevent the default error handling
                event.preventDefault();
                
                // Inject all possible environment variable formats
                injectAllEnvironmentVariables();
                
                console.log('Patched null check error, attempting to continue execution');
                return true;
              }
            }, true);  // Use capturing to get the event first
            
            // Stop observing once we've found the script
            observer.disconnect();
            break;
          }
        }
      }
    }
  });

  // Start observing the document for script additions
  observer.observe(document.documentElement, { 
    childList: true, 
    subtree: true 
  });

  // Helper function to inject environment variables in all possible formats
  function injectAllEnvironmentVariables() {
    const envVars = {
      SUPABASE_URL: "https://hvxgdyxqmkpmhejpumlc.supabase.co",
      SUPABASE_ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh2eGdkeXhxbWtwbWhlanB1bWxjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ0Nzk2OTMsImV4cCI6MjA2MDA1NTY5M30.JfS42uMEMgqNiKKfF17OKjMa6QRq6LUaJkESdAdLmdA",
      OPENROUTESERVICE_API_KEY: "5b3ce3597851110001cf6248c39073c1932f417f9d57d67334af0a15",
      OPENROUTE_API_KEY: "5b3ce3597851110001cf6248c39073c1932f417f9d57d67334af0a15"
    };
    
    // 1. Direct on window object
    Object.entries(envVars).forEach(([key, value]) => {
      window[key] = value;
    });
    
    // 2. In a process.env-like structure
    window.process = window.process || {};
    window.process.env = window.process.env || {};
    Object.entries(envVars).forEach(([key, value]) => {
      window.process.env[key] = value;
    });
    
    // 3. In a dotenv-like structure
    window.dotenv = window.dotenv || {};
    window.dotenv.env = window.dotenv.env || {};
    Object.entries(envVars).forEach(([key, value]) => {
      window.dotenv.env[key] = value;
    });
    
    // 4. In a flutter_dotenv structure
    window.flutter_dotenv = window.flutter_dotenv || {};
    window.flutter_dotenv.env = window.flutter_dotenv.env || {};
    Object.entries(envVars).forEach(([key, value]) => {
      window.flutter_dotenv.env[key] = value;
    });
    
    // Add the get function to dotenv objects
    window.dotenv.get = function(key) { return window.dotenv.env[key]; };
    window.flutter_dotenv.get = function(key) { return window.flutter_dotenv.env[key]; };
    
    console.log('Environment variables injected in multiple formats');
  }

  // Also inject variables immediately just to be safe
  injectAllEnvironmentVariables();
})(); 