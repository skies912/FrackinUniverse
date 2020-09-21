require "/stats/effects/fu_armoreffects/setbonuses_common.lua"
setName="fu_radienleatherset"

weaponBonus={
	{stat = "maxHealth", effectiveMultiplier = 1.15}
}

armorBonus={
	{stat = "powerMultiplier", effectiveMultiplier = 1.05}
}

biomeBonus={
	{stat = "grit", amount=0.05},
	{stat = "maxEnergy", effectiveMultiplier = 1.05}
}

function init()
	setSEBonusInit(setName)
	effectHandlerList.weaponBonusHandle=effect.addStatModifierGroup({})
	checkWeapons()
	effectHandlerList.armorBonusHandle=effect.addStatModifierGroup(armorBonus)
	effectHandlerList.biomeBonusHandle=effect.addStatModifierGroup({})
	checkPlanet()
end

function update(dt)
	if not checkSetWorn(self.setBonusCheck) then
		effect.expire()
	else
		checkWeapons()
		checkPlanet()
		mcontroller.controlModifiers({
			speedModifier = 1.05
		})
	end
end

function checkWeapons()
	local weapons=weaponCheck({"radien"})
	if weapons["either"] then
		effect.setStatModifierGroup(effectHandlerList.weaponBonusHandle,weaponBonus)
	else
		effect.setStatModifierGroup(effectHandlerList.weaponBonusHandle,{})
	end
end

function checkPlanet()
	if checkBiome({"garden", "forest"}) then
		effect.setStatModifierGroup(effectHandlerList.biomeBonusHandle,armorBonus)
	else
		effect.setStatModifierGroup(effectHandlerList.biomeBonusHandle,{})
	end
end