from services.paths import resolve_asset

def get_svg_path(svg_name):
    return resolve_asset(f"svgs/{svg_name}.svg")