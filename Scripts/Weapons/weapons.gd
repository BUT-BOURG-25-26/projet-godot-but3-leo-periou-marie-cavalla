extends Node3D

enum WeaponType { MELEE, RANGED }
enum WeaponMeleeRange { SHORT, MEDIUM, LONG}

@export var damage: float
@export var reload_cooldown: float
@export var type: WeaponType
@export var weight: float

# Stats dépendantes du type
@export var melee_range: WeaponMeleeRange
@export var ranged_distance: float
