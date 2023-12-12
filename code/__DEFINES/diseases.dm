
#define DISEASE_LIMIT 1
#define VIRUS_SYMPTOM_LIMIT 6

//Visibility Flags
#define HIDDEN_SCANNER (1<<0)
#define HIDDEN_PANDEMIC (1<<1)

//Bitfield for Visibility Flags
DEFINE_BITFIELD(visibility_flags, list(
	"HIDDEN_FROM_ANALYZER" = HIDDEN_SCANNER,
	"HIDDEN_FROM_PANDEMIC" = HIDDEN_PANDEMIC,
))

//Disease Flags
#define CURABLE (1<<0)
#define CAN_CARRY (1<<1)
#define CAN_RESIST (1<<2)
#define CHRONIC (1<<3)

//Spread Flags
#define DISEASE_SPREAD_SPECIAL (1<<0)
#define DISEASE_SPREAD_NON_CONTAGIOUS (1<<1)
#define DISEASE_SPREAD_BLOOD (1<<2)
#define DISEASE_SPREAD_CONTACT_FLUIDS (1<<3)
#define DISEASE_SPREAD_CONTACT_SKIN (1<<4)
#define DISEASE_SPREAD_AIRBORNE (1<<5)

//Bitfield for Spread Flags
DEFINE_BITFIELD(spread_flags, list(
	"SPREAD_SPECIAL" = DISEASE_SPREAD_SPECIAL,
	"SPREAD_NON_CONTAGIOUS" = DISEASE_SPREAD_NON_CONTAGIOUS,
	"SPREAD_BLOOD" = DISEASE_SPREAD_BLOOD,
	"SPREAD_FLUIDS" = DISEASE_SPREAD_CONTACT_FLUIDS,
	"SPREAD_SKIN_CONTACT" = DISEASE_SPREAD_CONTACT_SKIN,
	"SPREAD_AIRBORNE" = DISEASE_SPREAD_AIRBORNE,
))

//Severity Defines
/// Diseases that buff, heal, or at least do nothing at all
#define DISEASE_SEVERITY_POSITIVE "Positive"
/// Diseases that may have annoying effects, but nothing disruptive (sneezing)
#define DISEASE_SEVERITY_NONTHREAT "Harmless"
/// Diseases that can annoy in concrete ways (dizziness)
#define DISEASE_SEVERITY_MINOR "Minor"
/// Diseases that can do minor harm, or severe annoyance (vomit)
#define DISEASE_SEVERITY_MEDIUM "Medium"
/// Diseases that can do significant harm, or severe disruption (brainrot)
#define DISEASE_SEVERITY_HARMFUL "Harmful"
/// Diseases that can kill or maim if left untreated (flesh eating, blindness)
#define DISEASE_SEVERITY_DANGEROUS "Dangerous"
/// Diseases that can quickly kill an unprepared victim (fungal tb, gbs)
#define DISEASE_SEVERITY_BIOHAZARD "BIOHAZARD"
/// Diseases that are uncurable (hms)
#define DISEASE_SEVERITY_UNCURABLE "Uncurable"

//Severity Guaranteed Cycles or how long before a disease can potentially self-cure
/// Positive diseases should not self-cure by themselves
#define DISEASE_CYCLES_POSITIVE 0
/// Roughly 5 minutes for a harmless virus
#define DISEASE_CYCLES_NONTHREAT 150
/// Roughly 4 minutes for a disruptive nuisance virus
#define DISEASE_CYCLES_MINOR 120
/// Roughly 3 minutes for a medium virus
#define DISEASE_CYCLES_MEDIUM 90
/// Roughly 2 minute for a dangerous virus
#define DISEASE_CYCLES_DANGEROUS 60
/// Roughly 1 minute for a biohazard kill-death-evil-bad virus
#define DISEASE_CYCLES_BIOHAZARD 30
