import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_ANON_KEY;

const supabase = supabaseUrl && supabaseKey && !supabaseUrl.includes('your-project')
  ? createClient(supabaseUrl, supabaseKey)
  : null;

const BUCKET = 'photos';

export async function uploadFile(buffer, fileName, contentType) {
  if (!supabase) throw new Error('Supabase 스토리지가 설정되지 않았습니다.');

  const { data, error } = await supabase.storage
    .from(BUCKET)
    .upload(fileName, buffer, { contentType, upsert: true });

  if (error) throw error;

  const { data: urlData } = supabase.storage
    .from(BUCKET)
    .getPublicUrl(data.path);

  return urlData.publicUrl;
}

export async function deleteFile(filePath) {
  if (!supabase) return;

  const { error } = await supabase.storage
    .from(BUCKET)
    .remove([filePath]);

  if (error) throw error;
}
