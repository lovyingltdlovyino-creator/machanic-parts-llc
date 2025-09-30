from pathlib import Path

path = Path(r"lib/main.dart")
text = path.read_text()

text = text.replace(".in_('listing_id', ids)", ".inFilter('listing_id', ids)")

old_block = """        var query = Supabase.instance.client\n            .from('listings')\n            .select('''\n              *,\n              listing_photos(storage_path, sort_order)\n            ''')\n            .eq('status', 'active')\n            .order('created_at', ascending: false);\n\n        if (filters['category'] != null && filters['category'] != 'all') {\n          query = query.eq('category', filters['category']);\n        }\n        if (filters['condition'] != null && filters['condition'] != 'all') {\n          query = query.eq('condition', filters['condition']);\n        }\n        if (filters['part_name'] != null && filters['part_name'].toString().isNotEmpty) {\n          final q = filters['part_name'];\n          query = query.or('title.ilike.%$q%,description.ilike.%$q%');\n        }\n        if (filters['make'] != null && filters['make'].toString().isNotEmpty) {\n          query = query.ilike('make', '%${filters['make']}%');\n        }\n        if (filters['model'] != null && filters['model'].toString().isNotEmpty) {\n          query = query.ilike('model', '%${filters['model']}%');\n        }\n        if (filters['year'] != null) {\n          query = query.eq('year', filters['year']);\n        }\n\n        final resp = await query;"""

new_block = """        final supabase = Supabase.instance.client;\n        var query = supabase\n            .from('listings')\n            .select('''\n              *,\n              listing_photos(storage_path, sort_order)\n            ''')\n            .eq('status', 'active');\n\n        if (filters['category'] != null && filters['category'] != 'all') {\n          query = query.eq('category', filters['category']);\n        }\n        if (filters['condition'] != null && filters['condition'] != 'all') {\n          query = query.eq('condition', filters['condition']);\n        }\n        if (filters['part_name'] != null && filters['part_name'].toString().isNotEmpty) {\n          final q = filters['part_name'];\n          query = query.or('title.ilike.%$q%,description.ilike.%$q%');\n        }\n        if (filters['make'] != null && filters['make'].toString().isNotEmpty) {\n          query = query.ilike('make', '%${filters['make']}%');\n        }\n        if (filters['model'] != null && filters['model'].toString().isNotEmpty) {\n          query = query.ilike('model', '%${filters['model']}%');\n        }\n        if (filters['year'] != null) {\n          query = query.eq('year', filters['year']);\n        }\n\n        final resp = await query.order('created_at', ascending: false);"""

if old_block not in text:
    raise SystemExit('Old block not found')

text = text.replace(old_block, new_block, 1)

path.write_text(text)
