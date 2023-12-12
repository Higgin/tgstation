/datum/disease
	//Flags
	var/visibility_flags = NONE
	var/disease_flags = CURABLE|CAN_CARRY|CAN_RESIST
	var/spread_flags = DISEASE_SPREAD_AIRBORNE | DISEASE_SPREAD_CONTACT_FLUIDS | DISEASE_SPREAD_CONTACT_SKIN

	//Fluff
	var/form = "Virus"
	var/name = "No disease"
	var/desc = ""
	var/agent = "some microbes"
	var/spread_text = ""
	var/cure_text = ""

	//Stages
	var/stage = 1
	var/max_stages = 0
	/// The probability of this infection advancing a stage every second the cure is not present.
	var/stage_prob = 2
	/// How long this infection incubates (non-visible) before revealing itself
	var/incubation_time
	/// Has the virus hit its limit?
	var/stage_peaked = FALSE
	/// How many cycles has the virus been at its peak?
	var/peaked_cycles = 0
	/// How many cycles do we need to have been active after hitting our max stage to start rolling back?
	var/cycles_to_beat = 0

	//Other
	var/list/viable_mobtypes = list() //typepaths of viable mobs
	var/mob/living/carbon/affected_mob = null
	var/list/cures = list() //list of cures if the disease has the CURABLE flag, these are reagent ids
	/// The probability of spreading through the air every second
	var/infectivity = 41
	/// The probability of this infection being cured every second the cure is present
	var/cure_chance = 4
	var/carrier = FALSE //If our host is only a carrier
	var/bypasses_immunity = FALSE //Does it skip species virus immunity check? Some things may diseases and not viruses
	var/spreading_modifier = 1
	var/severity = DISEASE_SEVERITY_NONTHREAT
	/// If the disease requires an organ for the effects to function, robotic organs are immune to disease unless inorganic biology symptom is present
	var/required_organ
	var/needs_all_cures = TRUE
	var/list/strain_data = list() //dna_spread special bullshit
	var/infectable_biotypes = MOB_ORGANIC //if the disease can spread on organics, synthetics, or undead
	var/process_dead = FALSE //if this ticks while the host is dead
	var/copy_type = null //if this is null, copies will use the type of the instance being copied

/datum/disease/Destroy()
	. = ..()
	if(affected_mob)
		remove_disease()
	SSdisease.active_diseases.Remove(src)

//add this disease if the host does not already have too many
/datum/disease/proc/try_infect(mob/living/infectee, make_copy = TRUE)
	infect(infectee, make_copy)
	return TRUE

//add the disease with no checks
/datum/disease/proc/infect(mob/living/infectee, make_copy = TRUE)
	var/datum/disease/D = make_copy ? Copy() : src
	LAZYADD(infectee.diseases, D)
	D.affected_mob = infectee
	SSdisease.active_diseases += D //Add it to the active diseases list, now that it's actually in a mob and being processed.

	D.after_add()
	infectee.med_hud_set_status()

	var/turf/source_turf = get_turf(infectee)
	log_virus("[key_name(infectee)] was infected by virus: [src.admin_details()] at [loc_name(source_turf)]")

///Proc to process the disease and decide on whether to advance, cure or make the symptoms appear. Returns a boolean on whether to continue acting on the symptoms or not.
/datum/disease/proc/stage_act(seconds_per_tick, times_fired)
	var/slowdown = HAS_TRAIT(affected_mob, TRAIT_VIRUS_RESISTANCE) ? 0.5 : 1 // spaceacillin slows stage speed by 50%
	var/recovery_prob = 0

	if(required_organ)
		if(!has_required_infectious_organ(affected_mob, required_organ))
			cure(add_resistance = FALSE)
			return FALSE

	if(has_cure())
		if(disease_flags & CHRONIC && SPT_PROB(cure_chance, seconds_per_tick))
			update_stage(1)
			to_chat(affected_mob, span_notice("Your chronic illness is alleviated a little, though it can't be cured!"))
			return
		if(SPT_PROB(cure_chance, seconds_per_tick))
			update_stage(max(stage - 1, 1))
		if(disease_flags & CURABLE && SPT_PROB(cure_chance, seconds_per_tick))
			cure()
			return FALSE
	else if(SPT_PROB(stage_prob*slowdown, seconds_per_tick))
		update_stage(min(stage + 1, max_stages))

	if(stage == max_stages && stage_peaked != TRUE) //mostly a sanity check in case we manually set a virus to max stages
		stage_peaked = TRUE

	if(stage_peaked && !disease_flags & CHRONIC && disease_flags & CURABLE)
		if(stage == max_stages) //every cycle we spend at max stage counts towards eventually curing the virus
			peaked_cycles += 1
		switch(severity)
			if(DISEASE_SEVERITY_POSITIVE) //good viruses don't go anywhere after hitting max stage unless you try to get rid of them by sleeping
				cycles_to_beat = DISEASE_CYCLES_POSITIVE
				if(affected_mob.satiety > 0)
					return
			if(DISEASE_SEVERITY_NONTHREAT)
				cycles_to_beat = DISEASE_CYCLES_NONTHREAT
			if(DISEASE_SEVERITY_MINOR)
				cycles_to_beat = DISEASE_CYCLES_MINOR
			if(DISEASE_SEVERITY_MEDIUM)
				cycles_to_beat = DISEASE_CYCLES_MEDIUM
			if(DISEASE_SEVERITY_DANGEROUS)
				cycles_to_beat = DISEASE_CYCLES_DANGEROUS
			if(DISEASE_SEVERITY_BIOHAZARD)
				cycles_to_beat = DISEASE_CYCLES_BIOHAZARD
	if(!disease_flags & CHRONIC || disease_flags & CURABLE)
		if(peaked_cycles > cycles_to_beat)
			recovery_prob += 1
			if(slowdown) //using antibiotics after somebody's basically peaked out can help get them over the finish line to kill a virus
				recovery_prob += (slowdown - 1)
		if(affected_mob.satiety < 0) //being malnourished makes it a lot harder to defeat your illness
			recovery_prob += -0.8
		if(affected_mob.mob_mood) // this and most other modifiers below a shameless rip from sleeping healing buffs, but feeling good helps make it go away quicker
			switch(affected_mob.mob_mood.sanity_level)
				if(SANITY_LEVEL_GREAT)
					recovery_prob += 0.2
				if(SANITY_LEVEL_NEUTRAL)
					recovery_prob += 0.1
				if(SANITY_LEVEL_DISTURBED)
					recovery_prob += 0
				if(SANITY_LEVEL_UNSTABLE)
					recovery_prob += 0
				if(SANITY_LEVEL_CRAZY)
					recovery_prob += -0.1
				if(SANITY_LEVEL_INSANE)
					recovery_prob += -0.2

	if(affected_mob.satiety > 0 && HAS_TRAIT(affected_mob, TRAIT_KNOCKEDOUT) && !disease_flags & CHRONIC || disease_flags & CURABLE)
		var/turf/rest_turf = get_turf(affected_mob)
		var/is_sleeping_in_darkness = rest_turf.get_lumcount() <= LIGHTING_TILE_IS_DARK

		if(affected_mob.is_blind_from(EYES_COVERED) || is_sleeping_in_darkness)
			recovery_prob += 0.1

		// sleeping in silence is always better
		if(HAS_TRAIT(affected_mob, TRAIT_DEAF))
			recovery_prob += 0.1

		// check for beds
		if((locate(/obj/structure/bed) in affected_mob.loc))
			recovery_prob += 0.2
		else if((locate(/obj/structure/table) in affected_mob.loc))
			recovery_prob += 0.1

		// don't forget the bedsheet
		if(locate(/obj/item/bedsheet) in affected_mob.loc)
			recovery_prob += 0.1

		// you forgot the pillow
		if(locate(/obj/item/pillow) in affected_mob.loc)
			recovery_prob += 0.1

		recovery_prob += 0.2 //any form of sleeping helps a little bit

	if(recovery_prob && !disease_flags & CHRONIC && disease_flags & CURABLE)
		if(SPT_PROB(recovery_prob, seconds_per_tick))
			if(stage == 1) //if we reduce FROM stage == 1, cure the virus
				if(affected_mob.satiety < 0)
					if(stage_peaked == FALSE) //if you didn't ride out the virus from its peak, if you're malnourished when it cures, you don't get resistance
						cure(add_resistance = FALSE)
					else if(prob(50)) //if you rode it out from the peak, coinflip on if you get resistance or not
						cure(add_resistance = TRUE)
				else
					cure(add_resistance = TRUE) //stay fed and cure it at any point, you're immune
			update_stage(max(stage - 1, 1))

	return !carrier

/datum/disease/proc/update_stage(new_stage)
	stage = new_stage
	if(new_stage == max_stages && !(stage_peaked)) //once a virus has hit its peak, set it to have done so
		stage_peaked = TRUE

/datum/disease/proc/has_cure()
	if(!(disease_flags & (CURABLE | CHRONIC)))
		return FALSE

	. = cures.len
	for(var/C_id in cures)
		if(!affected_mob.reagents.has_reagent(C_id))
			.--
	if(!. || (needs_all_cures && . < cures.len))
		return FALSE

//Airborne spreading
/datum/disease/proc/spread(force_spread = 0)
	if(!affected_mob)
		return

	if(!(spread_flags & DISEASE_SPREAD_AIRBORNE) && !force_spread)
		return

	if(HAS_TRAIT(affected_mob, TRAIT_VIRUS_RESISTANCE) || (affected_mob.satiety > 0 && prob(affected_mob.satiety/10)))
		return

	var/spread_range = 2

	if(force_spread)
		spread_range = force_spread

	var/turf/T = affected_mob.loc
	if(istype(T))
		for(var/mob/living/carbon/C in oview(spread_range, affected_mob))
			var/turf/V = get_turf(C)
			if(disease_air_spread_walk(T, V))
				C.AirborneContractDisease(src, force_spread)

/proc/disease_air_spread_walk(turf/start, turf/end)
	if(!start || !end)
		return FALSE
	while(TRUE)
		if(end == start)
			return TRUE
		var/turf/Temp = get_step_towards(end, start)
		if(!TURFS_CAN_SHARE(end, Temp)) //Don't go through a wall
			return FALSE
		end = Temp


/datum/disease/proc/cure(add_resistance = TRUE)
	if(severity == DISEASE_SEVERITY_UNCURABLE) //aw man :(
		return
	if(affected_mob)
		if(add_resistance && (disease_flags & CAN_RESIST))
			LAZYOR(affected_mob.disease_resistances, GetDiseaseID())
	qdel(src)

/datum/disease/proc/IsSame(datum/disease/D)
	if(istype(D, type))
		return TRUE
	return FALSE


/datum/disease/proc/Copy()
	//note that stage is not copied over - the copy starts over at stage 1
	var/static/list/copy_vars = list("name", "visibility_flags", "disease_flags", "spread_flags", "form", "desc", "agent", "spread_text",
									"cure_text", "max_stages", "stage_prob", "incubation_time", "viable_mobtypes", "cures", "infectivity", "cure_chance",
									"required_organ", "bypasses_immunity", "spreading_modifier", "severity", "needs_all_cures", "strain_data",
									"infectable_biotypes", "process_dead")

	var/datum/disease/D = copy_type ? new copy_type() : new type()
	for(var/V in copy_vars)
		var/val = vars[V]
		if(islist(val))
			var/list/L = val
			val = L.Copy()
		D.vars[V] = val
	return D

/datum/disease/proc/after_add()
	return


/datum/disease/proc/GetDiseaseID()
	return "[type]"

/datum/disease/proc/remove_disease()
	LAZYREMOVE(affected_mob.diseases, src) //remove the datum from the list
	affected_mob.med_hud_set_status()
	affected_mob = null

/**
 * Checks the given typepath against the list of viable mobtypes.
 *
 * Returns TRUE if the mob_type path is derived from of any entry in the viable_mobtypes list.
 * Returns FALSE otherwise.
 *
 * Arguments:
 * * mob_type - Type path to check against the viable_mobtypes list.
 */
/datum/disease/proc/is_viable_mobtype(mob_type)
	for(var/viable_type in viable_mobtypes)
		if(ispath(mob_type, viable_type))
			return TRUE

	// Let's only do this check if it fails. Did some genius coder pass in a non-type argument?
	if(!ispath(mob_type))
		stack_trace("Non-path argument passed to mob_type variable: [mob_type]")

	return FALSE

/// Checks if the mob has the required organ and it's not robotic or affected by inorganic biology
/datum/disease/proc/has_required_infectious_organ(mob/living/carbon/target, required_organ_slot)
	if(!iscarbon(target))
		return FALSE

	var/obj/item/organ/target_organ = target.get_organ_slot(required_organ_slot)
	if(!istype(target_organ))
		return FALSE

	// robotic organs are immune to disease unless 'inorganic biology' symptom is present
	if(IS_ROBOTIC_ORGAN(target_organ) && !(infectable_biotypes & MOB_ROBOTIC))
		return FALSE

	return TRUE

//Use this to compare severities
/proc/get_disease_severity_value(severity)
	switch(severity)
		if(DISEASE_SEVERITY_UNCURABLE)
			return 0
		if(DISEASE_SEVERITY_POSITIVE)
			return 1
		if(DISEASE_SEVERITY_NONTHREAT)
			return 2
		if(DISEASE_SEVERITY_MINOR)
			return 3
		if(DISEASE_SEVERITY_MEDIUM)
			return 4
		if(DISEASE_SEVERITY_HARMFUL)
			return 5
		if(DISEASE_SEVERITY_DANGEROUS)
			return 6
		if(DISEASE_SEVERITY_BIOHAZARD)
			return 7
