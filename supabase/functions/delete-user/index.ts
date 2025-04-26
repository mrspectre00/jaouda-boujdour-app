// Supabase Edge Function to securely delete a user from the auth system
// This function runs with admin privileges and should be protected by RLS policies

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

serve(async (req) => {
  try {
    // Create Supabase admin client with service_role key
    const supabaseAdmin = createClient(
      // Supabase API URL - env var injected by default
      Deno.env.get("SUPABASE_URL") ?? "",
      // Supabase service_role key - env var injected by default
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );

    // Get the request body
    const { userId } = await req.json();

    // Validate input
    if (!userId) {
      return new Response(
        JSON.stringify({ error: "User ID is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Check if user exists first
    const { data: userData, error: userError } = await supabaseAdmin.auth.admin.getUserById(userId);
    
    if (userError || !userData) {
      console.error("Error retrieving user:", userError);
      return new Response(
        JSON.stringify({ error: "User not found", details: userError }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    // Delete the user from auth system
    const { error } = await supabaseAdmin.auth.admin.deleteUser(userId);

    if (error) {
      console.error("Error deleting user:", error);
      return new Response(
        JSON.stringify({ error: "Failed to delete user", details: error }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: true, message: "User deleted successfully" }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("Unexpected error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: err.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}); 