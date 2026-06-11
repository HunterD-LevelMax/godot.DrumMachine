## game_settings.gd
## Autoload singleton. Holds persistent player preferences for the session.
## Add save/load to user:// here when persistence across launches is needed.
extends Node

const MIN_VOLUME_DB := -40.0
const MAX_VOLUME_DB :=   0.0

var master_volume_db: float = 0.0
