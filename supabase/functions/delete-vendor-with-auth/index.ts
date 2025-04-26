import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'
import { corsHeaders } from '../_shared/cors.ts'

interface RequestBody {
  vendorId: string
}

serve(async (req) => {
  // Handle CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // Create a Supabase client with the admin key
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const supabase = createClient(supabaseUrl, supabaseServiceKey)

  console.log('Delete vendor with auth function called')

  // Get the authorization header from the request
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: 'Missing Authorization header' }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // Verify the requesting user has admin rights
  const token = authHeader.replace('Bearer ', '')
  const { data: { user }, error: authError } = await supabase.auth.getUser(token)
  
  if (authError || !user) {
    console.error('Auth error:', authError)
    return new Response(
      JSON.stringify({ error: 'Unauthorized' }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  console.log('Auth successful for user:', user.id)

  // Check if the user has the admin role
  const { data: vendor, error: vendorError } = await supabase
    .from('vendors')
    .select('is_management')
    .eq('user_id', user.id)
    .single()

  if (vendorError) {
    console.error('Error checking management status:', vendorError)
  }

  if (!vendor || !vendor.is_management) {
    return new Response(
      JSON.stringify({ error: 'Forbidden: Admin access required' }),
      { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  console.log('Management check passed')

  try {
    // Parse the request body to get the vendor ID
    const { vendorId } = await req.json() as RequestBody

    if (!vendorId) {
      return new Response(
        JSON.stringify({ error: 'Vendor ID is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('Processing deletion for vendor ID:', vendorId)

    // Get the vendor's auth user ID
    const { data: vendorToDelete, error: vendorError } = await supabase
      .from('vendors')
      .select('user_id')
      .eq('id', vendorId)
      .single()

    if (vendorError) {
      console.error('Error finding vendor:', vendorError)
    }

    if (!vendorToDelete) {
      return new Response(
        JSON.stringify({ error: 'Vendor not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('Found vendor with user_id:', vendorToDelete.user_id)

    // Delete the vendor from the database first
    const { error: deleteVendorError } = await supabase
      .from('vendors')
      .delete()
      .eq('id', vendorId)

    if (deleteVendorError) {
      console.error('Error deleting vendor from database:', deleteVendorError)
      throw new Error(`Failed to delete vendor: ${deleteVendorError.message}`)
    }

    console.log('Vendor deleted from database, now deleting auth user')

    // Delete the auth user if there's a user_id
    if (vendorToDelete.user_id) {
      console.log('Attempting to delete auth user:', vendorToDelete.user_id)
      const { error: deleteAuthError } = await supabase.auth.admin.deleteUser(
        vendorToDelete.user_id
      )

      if (deleteAuthError) {
        console.error('Error deleting auth user:', deleteAuthError)
        // Log the error but don't throw, as the vendor record is already deleted
        // and we don't want to fail the entire operation
        return new Response(
          JSON.stringify({ 
            message: 'Vendor record deleted, but failed to delete auth user',
            error: deleteAuthError.message
          }),
          { status: 207, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      console.log('Auth user deleted successfully')
    } else {
      console.log('No user_id found for vendor, skipping auth user deletion')
    }

    return new Response(
      JSON.stringify({ message: 'Vendor deleted successfully' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Unhandled error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
}) 