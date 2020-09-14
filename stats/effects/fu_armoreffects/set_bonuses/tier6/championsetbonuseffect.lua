require "/stats/effects/fu_armoreffects/setbonuses_common.lua"

setName="fu_championset"

weaponBonus={
	{stat = "powerMultiplier", effectiveMultiplier = 1.30},
	{stat = "critChance", amount = 3}
}

armorBonus={
	{stat = "fumudslowImmunity", amount = 1},
	{stat = "blacktarImmunity", amount = 1},
	{stat = "biomecoldImmunity", amount = 1}
}

function init()
	setSEBonusInit(setName)
	effectHandlerList.weaponBonusHandle=effect.addStatModifierGroup({})
			
	checkWeapons()

	effectHandlerList.armorBonusHandle=effect.addStatModifierGroup(armorBonus)
end

function update(dt)
	if not checkSetWorn(self.setBonusCheck) then
		effect.expire()
	else
		effect.setStatModifierGroup(effectHandlerList.armorBonusHandle,armorBonus)
		checkWeapons()
	end
end

function checkWeapons()
	local weapons=weaponCheck({"axe","hammer","mace"})
	
	if weapons["either"] then
		effect.setStatModifierGroup(effectHandlerList.weaponBonusHandle,weaponBonus)
	else
		effect.setStatModifierGroup(effectHandlerList.weaponBonusHandle,{})
	end
end