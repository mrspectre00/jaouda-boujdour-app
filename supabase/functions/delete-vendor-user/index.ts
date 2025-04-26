// Follow this setup guide to integrate the Deno runtime into your project:
// https://deno.land/manual/getting_started/setup_your_environment

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface RequestData {
  vendorId: string;
}

const PROTECTED_VENDOR_IDS = ['1']; // Default admin vendor can't be deleted

serve(async (req) => {
  try {
    // Get request body
    const requestData: RequestData = await req.json();
    const { vendorId } = requestData;
    
    // Create a Supabase client with the service role key
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );
    
    // Check for admin authorization
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Not authorized" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }
    
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token);
    
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Not authorized" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }
    
    // Check if calling user is admin
    const { data: callerData, error: callerError } = await supabaseAdmin
      .from("vendors")
      .select("is_management")
      .eq("user_id", user.id)
      .single();
      
    if (callerError || !callerData || !callerData.is_management) {
      return new Response(
        JSON.stringify({ error: "Not authorized - requires management role" }),
        { status: 403, headers: { "Content-Type": "application/json" } }
      );
    }
    
    // Check if trying to delete a protected vendor
    if (PROTECTED_VENDOR_IDS.includes(vendorId)) {
      return new Response(
        JSON.stringify({ error: "This vendor account is protected and cannot be deleted" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }
    
    // Get the vendor to be deleted to find their auth user_id
    const { data: vendorData, error: vendorError } = await supabaseAdmin
      .from("vendors")
      .select("user_id")
      .eq("id", vendorId)
      .single();
      
    if (vendorError || !vendorData) {
      return new Response(
        JSON.stringify({ error: "Vendor not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }
    
    // Delete the vendor's data records first
    // For example, delete related records in other tables
    // This would be a good place to implement a transaction if needed
    
    // Delete the vendor record from the database
    const { error: deleteVendorError } = await supabaseAdmin
      .from("vendors")
      .delete()
      .eq("id", vendorId);
      
    if (deleteVendorError) {
      return new Response(
        JSON.stringify({ error: `Failed to delete vendor: ${deleteVendorError.message}` }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }
    
    // Delete the auth user
    const { error: deleteUserError } = await supabaseAdmin.auth.admin.deleteUser(
      vendorData.user_id
    );
    
    if (deleteUserError) {
      return new Response(
        JSON.stringify({ 
          warning: `Vendor record deleted, but failed to delete auth user: ${deleteUserError.message}`,
          success: true
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }
    
    return new Response(
      JSON.stringify({
        message: "Vendor user deleted successfully",
        success: true
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: `Server error: ${error.message}` }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}); 