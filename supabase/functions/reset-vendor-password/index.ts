// Follow this setup guide to integrate the Deno runtime into your project:
// https://deno.land/manual/getting_started/setup_your_environment

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

interface RequestBody {
  email: string;
  newPassword: string;
}

serve(async (req) => {
  // Create a Supabase client with the admin key
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  // Get the authorization header from the request
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: "Missing Authorization header" }),
      { status: 401, headers: { "Content-Type": "application/json" } }
    );
  }

  // Verify the requesting user has admin rights
  const token = authHeader.replace("Bearer ", "");
  const { data: { user }, error: authError } = await supabase.auth.getUser(token);
  
  if (authError || !user) {
    return new Response(
      JSON.stringify({ error: "Unauthorized" }),
      { status: 401, headers: { "Content-Type": "application/json" } }
    );
  }

  // Check if the user has the admin role
  const { data: vendor, error: vendorError } = await supabase
    .from("vendors")
    .select("is_management")
    .eq("user_id", user.id)
    .single();

  if (vendorError || !vendor || !vendor.is_management) {
    return new Response(
      JSON.stringify({ error: "Forbidden: Admin access required" }),
      { status: 403, headers: { "Content-Type": "application/json" } }
    );
  }

  try {
    // Parse the request body to get the email and new password
    const { email, newPassword } = await req.json() as RequestBody;

    if (!email || !newPassword) {
      return new Response(
        JSON.stringify({ error: "Email and new password are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Find the user by email
    const { data: userData, error: userError } = await supabase
      .from("vendors")
      .select("user_id")
      .eq("email", email)
      .single();

    if (userError || !userData || !userData.user_id) {
      return new Response(
        JSON.stringify({ error: "Vendor not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    // Update the user's password
    const { error: updateError } = await supabase.auth.admin.updateUserById(
      userData.user_id,
      { password: newPassword }
    );

    if (updateError) {
      throw new Error(`Failed to update password: ${updateError.message}`);
    }

    return new Response(
      JSON.stringify({ message: "Password updated successfully" }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error:", error.message);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}); 