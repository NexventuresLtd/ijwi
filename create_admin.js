const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: '.env.local' });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error("Missing supabase URL or service role key.");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function run() {
  const email = 'niyonshutidavid49@gmail.com';
  const password = 'NIYO@DAVID';

  const { data: { users }, error: listError } = await supabase.auth.admin.listUsers();
  if (listError) return console.log('Error listing users:', listError);
  
  let user = users.find(u => u.email === email);
  if (user) {
    console.log('User exists. Updating password...');
    const { error: updateError } = await supabase.auth.admin.updateUserById(user.id, { password, email_confirm: true });
    if (updateError) console.log('Error updating:', updateError);
    else {
      console.log('Password updated.');
      await supabase.from('profiles').update({ is_admin: true }).eq('id', user.id);
    }
  } else {
    console.log('Creating user...');
    const { data, error } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true
    });
    if (error) console.log('Error creating:', error);
    else {
      console.log('Created user:', data.user.id);
      await supabase.from('profiles').update({ is_admin: true }).eq('id', data.user.id);
      console.log('Set is_admin to true.');
    }
  }
}
run();
