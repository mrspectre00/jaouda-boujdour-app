import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://hvxgdyxqmkpmhejpumlc.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh2eGdkeXhxbWtwbWhlanB1bWxjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ0Nzk2OTMsImV4cCI6MjA2MDA1NTY5M30.JfS42uMEMgqNiKKfF17OKjMa6QRq6LUaJkESdAdLmdA';

export const supabase = createClient(supabaseUrl, supabaseKey);