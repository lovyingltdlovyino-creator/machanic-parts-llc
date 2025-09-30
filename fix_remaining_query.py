from pathlib import Path

path = Path(r"lib/main.dart")
text = path.read_text()

# Fix the remaining query builder issue - move filters before order
old_block = """        var query = Supabase.instance.client\n            .from('listings')\n            .select('''\n              *,\n              listing_photos(storage_path, sort_order)\n            ''')\n            .eq('status', 'active')\n            .order('created_at', ascending: false);\n        \n        // Apply filters\n        if (filters['part_name'] != null) {\n          query = query.or('title.ilike.%${filters['part_name']}%,description.ilike.%${filters['part_name']}%');\n        }\n        if (filters['category'] != null) {\n          query = query.eq('category', filters['category']);\n        }\n        if (filters['condition'] != null) {\n          query = query.eq('condition', filters['condition']);\n        }\n        if (filters['make'] != null) {\n          query = query.ilike('make', '%${filters['make']}%');\n        }\n        if (filters['model'] != null) {\n          query = query.ilike('model', '%${filters['model']}%');\n        }\n        if (filters['year'] != null) {\n          query = query.eq('year', filters['year']);\n        }\n        \n        response = await query;"""

new_block = """        var query = Supabase.instance.client\n            .from('listings')\n            .select('''\n              *,\n              listing_photos(storage_path, sort_order)\n            ''')\n            .eq('status', 'active');\n        \n        // Apply filters\n        if (filters['part_name'] != null) {\n          query = query.or('title.ilike.%${filters['part_name']}%,description.ilike.%${filters['part_name']}%');\n        }\n        if (filters['category'] != null) {\n          query = query.eq('category', filters['category']);\n        }\n        if (filters['condition'] != null) {\n          query = query.eq('condition', filters['condition']);\n        }\n        if (filters['make'] != null) {\n          query = query.ilike('make', '%${filters['make']}%');\n        }\n        if (filters['model'] != null) {\n          query = query.ilike('model', '%${filters['model']}%');\n        }\n        if (filters['year'] != null) {\n          query = query.eq('year', filters['year']);\n        }\n        \n        response = await query.order('created_at', ascending: false);"""

if old_block not in text:
    raise SystemExit('Old block not found')

text = text.replace(old_block, new_block, 1)
path.write_text(text)
