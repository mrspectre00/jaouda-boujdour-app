import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface VendorData {
  name: string
  email: string
  region_id: string | null
  phone?: string
  address?: string
  is_active: boolean
  is_management: boolean
  created_at: string
  updated_at: string
}

interface RequestData {
  email: string
  password: string
  userData: VendorData
}

serve(async (req) => {
  try {
    // Get request body
    const requestData: RequestData = await req.json()
    const { email, password, userData } = requestData
    
    // Create a Supabase client with the service role key
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )
    
    // Check for admin authorization
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Not authorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token)
    
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Not authorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    // Check if calling user is admin
    const { data: callerData, error: callerError } = await supabaseAdmin
      .from('vendors')
      .select('is_management')
      .eq('user_id', user.id)
      .single()
      
    if (callerError || !callerData || !callerData.is_management) {
      return new Response(
        JSON.stringify({ error: 'Not authorized - requires management role' }),
        { status: 403, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Create the auth user
    const { data: authData, error: createUserError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    })

    if (createUserError) {
      return new Response(
        JSON.stringify({ error: `Failed to create auth user: ${createUserError.message}` }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Create the vendor record in the database
    const { data: vendorData, error: vendorError } = await supabaseAdmin
      .from('vendors')
      .insert({
        ...userData,
        user_id: authData.user.id,
      })
      .select()
      .single()

    if (vendorError) {
      // Attempt to clean up the auth user if the vendor creation fails
      await supabaseAdmin.auth.admin.deleteUser(authData.user.id)
      
      return new Response(
        JSON.stringify({ error: `Failed to create vendor: ${vendorError.message}` }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({
        message: 'Vendor user created successfully',
        vendor: vendorData,
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: `Server error: ${error.message}` }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
}) 