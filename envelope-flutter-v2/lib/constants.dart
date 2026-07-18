import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl     = 'https://enqltolmazmrkdghitae.supabase.co';
const supabaseAnonKey = 'sb_publishable_2Msl4wQ-mqg_6TQwjqjqhA_cfF-_FyY';

// Sentry — cole sua DSN aqui após criar o projeto em sentry.io
const sentryDsn = 'https://fe625e016ac5422fee8f21936bb5518c@o4511733735882752.ingest.de.sentry.io/4511733741060176';

final supabase = Supabase.instance.client;
