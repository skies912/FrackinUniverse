require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
	-- passive research gain
	self.researchCount = player.currency("fuscienceresource") or 0
	self.baseVal = config.getParameter("baseValue") or 1
    self.timerCounter = 0

	self.madnessCount = player.currency("fumadnessresource") or 0
	self.timer = 10.0 -- was zero, instant event on plopping in. giving players a short grace period. some of us teleport around a LOT.
	self.player = entity.id()
	math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )
	self.randEvent = math.random(1,100)
	self.timerDegrade = math.random(1,12)
	self.degradeTotal = 0
	self.bonusTimer = 1

	status.removeEphemeralEffect("partytime5")--make sure the annoying sounds dont flood
	status.removeEphemeralEffect("partytime4")
	status.removeEphemeralEffect("partytime3")
	status.removeEphemeralEffect("partytime2")

	self.paintTimer = 0

	self.playerId = entity.id()
	self.maxMadnessValue = 15000
	self.madnessPercent = math.min(self.madnessCount / self.maxMadnessValue,1.0)

	self.barName = "madnessBar"
	self.barColor = {250,0,250,125}
	self.timerReloadBar = 0
	self.timerRemoveAmmoBar = 0
	
	local elementalTypes=root.assetJson("/damage/elementaltypes.config")
	local buffer={}
	
	for element,data in pairs(elementalTypes) do
		if data.resistanceStat then
			buffer[data.resistanceStat]=true
		end
	end
	self.resistList={}
	for stat,_ in pairs(buffer) do
		table.insert(self.resistList,stat)
	end
end

function randomEvent()
	if not self.madnessCount then init() end
	status.setPersistentEffects("madnessEffectsMain",{})--reset persistent effects the next time one pops up.
	self.randEvent=math.random(1,100)
	self.currentPrimary = world.entityHandItem(entity.id(), "primary")	--what are we carrying in the right hand?
	self.currentSecondary = world.entityHandItem(entity.id(), "alt")	--what are we carrying in the left hand?
	self.isProtectedRand = math.random(1,100)
	self.isProtectedRandVal = self.isProtectedRand / 100
	self.currentProtection = status.stat("mentalProtection") or 0
	
	--mentalProtection can make it harder to be affected
	if (status.statPositive("mentalProtection")) and (self.isProtectedRandVal <= status.stat("mentalProtection")) then
		self.randEvent = self.randEvent - (self.currentProtection * 10) --math.random(10,70)	--it doesnt *remove* the effect, it just moves it further up the list, and potentially off of it.
	end
	
	-- are we currently carrying any really weird stuff?
	isWeirdStuff(self.timer)

	--set duration of curse
	self.curseDuration = math.min(self.timer,self.madnessCount / 5) --this value will be adjusted based on effect type. Clamping this because it's too much otherwise.
	--at 15k madness, that's 15000/5, or 1000 seconds. 16.6~ mins. ew.
	--of course, with 0 madness resistance, that means self.timer will be 150. What this results in is a steady growth, followed by a petering off curve as effect frequency increases.
	--Effects will be more frequent, and more potent overall, as madness increases. This implements a bit of a ceiling on how bad it can get.
	self.curseDuration_status = self.curseDuration * 2
	self.curseDuration_annoy = self.curseDuration * 1.2
	self.curseDuration_resource = self.curseDuration * 2.2
	self.curseDuration_stat = self.curseDuration * 2.5
	self.curseDuration_fast = self.curseDuration *0.25
	status.addEphemeralEffect("mad",self.timer)


	if self.randEvent < 0 then --failsafe
		self.randEvent = 0
	end

	if self.madnessCount > 1500 then
		if self.randEvent == 44 then
			status.addEphemeralEffect("eatself",20) -- You just can't stop eating yourself.
			status.addEphemeralEffect("healingimmunitydummy",20) -- healing won't work on you
			if status.isResource("food") then
				status.addEphemeralEffect("convert_food-health_100_1-10_lethal",20) -- So hungry...
				status.addEphemeralEffect("feedpackneg",self.curseDuration_status)-- hunger isn't abating so fast.
			else
				status.addEphemeralEffect("heal_neg20",20) -- It gnaws at you.
			end
		elseif self.randEvent == 45 then
			status.addEphemeralEffect("runboost15",self.curseDuration_status) -- run boost!
		end
	end
	if self.madnessCount > 1000 then
		if self.randEvent >= 40 and self.randEvent <= 42 then
			local enabledtechs=player.enabledTechs()
			if self.randEvent == 40 and contains(enabledtechs,"distortionsphere") then --swap sphere tech
				player.equipTech("distortionsphere")
			elseif self.randEvent == 41 and contains(enabledtechs,"doublejump") then --swap jump tech
				player.equipTech("doublejump")
			elseif self.randEvent == 42 and contains(enabledtechs,"dash") then --swap dash tech
				player.equipTech("dash")
			end
		elseif self.randEvent == 43 then
			player.consumeCurrency("fuscienceresource", 1)
			player.radioMessage("sanitygain")
		end
	end
	if self.madnessCount > 750 then
		if self.randEvent == 37 and self.madnessCount > 800 then
			if (self.currentPrimary and root.itemHasTag(self.currentPrimary, "dagger")) or (self.currentSecondary and root.itemHasTag(self.currentSecondary, "dagger")) then --if holding a knife, cut yourself
				status.addEphemeralEffect("bleeding05",self.curseDuration_status) -- You just can't stop stabbing yourself
				player.radioMessage("madnessharm")
			else
				self.timerDegradePenalty = 10
			end
		elseif self.randEvent == 38 and self.madnessCount > 800 then
			status.addEphemeralEffect("runboost10",self.curseDuration_status) -- run boost!
			self.timerDegradePenalty = 2
		elseif self.randEvent == 39 and self.madnessCount > 900 then
			status.addEphemeralEffect("rootfu",10) -- unable to move
			player.radioMessage("madnessroot")
		elseif self.randEvent == 53 then
			--local penaltyValue = math.random(1,100)/100 --while we could make it apply this to all of them, it's better to apply it randomly to all of them!
			local buffer={}
			for _,stat in pairs(self.resistList) do
				table.insert(buffer,{stat=stat,amount=((math.random()>0.75 and 1) or (-1))*(math.random(1,20)/100.0)}) --still, needed to reduce the maximum range to reasonable levels. also added a chance for a bonus
			end
			status.setPersistentEffects("madnessEffectsMain", buffer)
			--same problem as the 'pick random resist' debuff. 
		end
	end
	if self.madnessCount > 500 then
		if self.randEvent == 30 then
			status.addEphemeralEffect("percentarmorboostneg"..tostring(math.random(1,5)),self.curseDuration_status)--randomly get a penalty multiplier of 0.9 to 0.5 for defense
		elseif self.randEvent == 31 then
			status.addEphemeralEffect("feedpackneg",self.curseDuration_status) --more hunger
			player.radioMessage("madnessfood")
		elseif self.randEvent == 32 then
			status.addEphemeralEffect("runboostdebuff",self.curseDuration_status) -- run boost!
			player.radioMessage("madness2")
		elseif self.randEvent == 33 then
			status.addEphemeralEffect("swimboost2",self.curseDuration_status) -- Swim boost2!
		elseif self.randEvent == 34 then
			if player.isLounging() then
				status.addEphemeralEffect("burning",self.curseDuration_status)--your ass is on fire.
				player.radioMessage("combust")
			end
		elseif self.randEvent == 35 then
			status.addEphemeralEffect("fu_nooxygen",self.curseDuration_status) -- You have forgotten how to breathe
		elseif self.randEvent == 36 then
			status.addEphemeralEffect("jumpboost25neg",self.curseDuration_status) -- You suddenly suck at jumping
			player.radioMessage("madness2")
		elseif (self.randEvent >= 46 and self.randEvent <= 52) then
			status.setPersistentEffects("madnessEffectsMain", {{stat = self.resistList[math.random(1,#self.resistList)], amount = ((math.random()>0.75 and 1) or (-1))*math.random(1,20)/100.0}}) -- pick one from all available resistances, and reduce it by 1-X%
		end
	end
	if self.madnessCount > 200 then
		if self.randEvent == 11 then
			status.addEphemeralEffect("nude",self.curseDuration_status) --harmless, but silly. YOU ARE NAKEY!
		elseif self.randEvent == 12 then
			status.addEphemeralEffect("staffslow2",self.curseDuration_status) -- obnoxious.
		elseif self.randEvent == 13 then
			status.addEphemeralEffect("medicaltoxiccloud",self.curseDuration) -- should probably swap for a madness specific variant.
		elseif self.randEvent == 14 then
			status.addEphemeralEffect("loweredshadow",self.curseDuration_status) --more susceptible to shadow
		elseif self.randEvent == 15 then
			status.addEphemeralEffect("ffbiomecold0",self.curseDuration_status) --player feels cold
		elseif self.randEvent == 16 then
			status.addEphemeralEffect("jungleweathernew",self.curseDuration_status) --player feels hot
		elseif self.randEvent == 17 then
			status.addEphemeralEffect("insanity",self.curseDuration_status) --player feels insane
		elseif self.randEvent == 18 then
			status.addEphemeralEffect("slow",self.curseDuration_status) --slows the player for a while
			player.radioMessage("madness2")
		elseif self.randEvent == 19 then
			status.addEphemeralEffect("runboost5",curseDuration_fast) -- run boost 5!
		elseif self.randEvent == 20 then
			status.addEphemeralEffect("maxhealthboostneg20",self.curseDuration_status) -- lowered health
		elseif self.randEvent == 21 then
			status.addEphemeralEffect("maxenergyboostneg20",self.curseDuration_status) -- lowered energy
		elseif self.randEvent == 22 then
			status.addEphemeralEffect("lowgrav_fallspeedup",curseDuration_fast) -- adjusts gravity
		elseif self.randEvent == 23 then
			status.addEphemeralEffect("slimeleech",self.curseDuration_status) -- slimeleech. ew.
		elseif self.randEvent == 24 then
			status.addEphemeralEffect("knockbackWeaknessHidden",self.curseDuration_status) -- Knockbacks affect you more
		elseif self.randEvent == 25 then
			status.addEphemeralEffect("swimboost1",self.curseDuration_status) -- Swim boost 1!
		elseif self.randEvent == 26 then
			status.addEphemeralEffect("vulnerability",self.curseDuration_fast) --vulnerability multiplies all resists and defense by 0.01, biiiig ouch. severely reducing the max duration of this.
		elseif self.randEvent == 27 then
			status.setPersistentEffects("madnessEffectsMain", {{stat = "fuCharisma", baseMultiplier = (1.0-(math.random(6,40)/100.0)) }}) --random charisma penalty.
		elseif self.randEvent == 28 then
			if status.isResource("food") then
				status.setResource("food",math.random(1.0,status.stat("maxFood"))) --your current hunger is randomized
			end
			player.radioMessage("madnessfood")
		elseif self.randEvent == 29 then --max food reduction
			status.setPersistentEffects("madnessEffectsMain", {{stat = "maxFood", amount = -1*math.random(1,8)}})
		end
	end
	if self.madnessCount > 150 then
		if self.randEvent == 6 then
			status.addEphemeralEffect("partytime2",self.curseDuration_annoy) -- party
		elseif self.randEvent == 7 then
			status.addEphemeralEffect("partytime3",self.curseDuration_annoy) -- party
		elseif self.randEvent == 8 then
			status.addEphemeralEffect("partytime4",self.curseDuration_annoy) -- party
		elseif self.randEvent == 9 then
			status.addEphemeralEffect("partytime5",self.curseDuration_annoy) -- party
		elseif self.randEvent == 10 then
			player.addCurrency("fuscienceresource", 1)
		end
	end
	if self.madnessCount > 50 then
		if self.randEvent == 1 then
			status.addEphemeralEffect("booze",self.curseDuration_status) --player feels drunk
		elseif self.randEvent == 2 then
			status.addEphemeralEffect("biomeairless",self.curseDuration_status)--annoying harmless warning
		elseif self.randEvent == 3 then
			status.addEphemeralEffect("sandstorm",self.curseDuration_status)--you farted sand
		elseif self.randEvent == 4 then
			status.setPersistentEffects("madnessEffectsMain", {{stat = "mentalProtection", amount = status.stat("mentalProtection") + 0.5 }}) --temporary protection from madness
		elseif self.randEvent == 5 then
			if player.hasCountOfItem("plantfibre") then -- consume a plant fibre, just to confuse and confound
				player.consumeItem("plantfibre", true, false)
				player.radioMessage("madness1")
			end
		end
	end
end

function update(dt)
    self.motionX = mcontroller.xVelocity()
	--passive research gain
	--if status.statusProperty("fu_creationDate") then
	--	self.bonus = status.stat("researchBonus") or 1
	--	if self.timerCounter >= 1 then
	--		player.addCurrency("fuscienceresource",1 + self.bonus)
	--		self.timerCounter = 0
	--	else
	--		self.timerCounter = self.timerCounter + 1
	--	end			
	--end

	-- we control the ammo bar removal from here for now, since its innocuous enough to work without interfering with update() on the player
	-- there are better places to put it, but this at least keeps it contained
	if (self.timerRemoveAmmoBar >=6) then
		world.sendEntityMessage(entity.id(),"removeBar","ammoBar")	--clear ammo bar
		self.timerRemoveAmmoBar = 0
	else
		self.timerRemoveAmmoBar = math.min(self.timerRemoveAmmoBar + dt,6.0)
	end

	self.madnessCount = player.currency("fumadnessresource")
	self.researchCount = player.currency("fuscienceresource") --passive research gain

	-- timing refresh for sculptures, painting effects
	self.paintTimer = math.max(0,self.paintTimer - dt)
	if self.paintTimer <= 0 then
		checkMadnessArt()
	end

	-- Core Adjustment Function
	self.timer = math.max(self.timer - dt,0.0)
	if self.timer <= 0.0 then
		if self.madnessCount > 50 then
			self.degradeTotal = self.madnessCount / 300 -- max is 50
			self.timerDegradePenalty = math.max(0.0,self.madnessCount / 500)
			self.timer = math.max(math.max(10,300.0 - (self.madnessCount/100)) + (status.stat("mentalProtection") * 100),10)--implementing a hard floor on how low the timer can go.
			randomEvent() --apply random effect
		else
			self.timer = 300.0
			self.degradeTotal = 1
		end
	end
	self.timerDegrade = math.max(self.timerDegrade - dt,0.0) 
	self.freudBonus = math.max(status.stat("freudBonus"),-0.8) -- divide by zero is bad. as this approaches -1, the timer approaches infinity. -0.5 turns the timer into 80s instead of 40s. cappin it at -0.8, which is 400s or 10x
	--gradually reduce Madness over time
	if (self.timerDegrade <= 0) then --no more limit to when it can degrade
		self.timerDegradePenalty = self.timerDegradePenalty or 0.0
		player.consumeCurrency("fumadnessresource", self.degradeTotal)
		self.timerDegrade= (60.0 - self.timerDegradePenalty) / (1.0+self.freudBonus)
		--displayBar()
	end
	-- apply bonus loss from anti-madness effects even if not above X madness
	self.bonusTimer = math.max(self.bonusTimer - dt,0)
	if self.bonusTimer <= 0.0 then
		self.protectionBonus = status.stat("mentalProtection")* 20 + math.random(1,12)
		if (status.statPositive("mentalProtection")) then
			player.consumeCurrency("fumadnessresource", self.protectionBonus)
		end
		self.bonusTimer = 40.0 / (1.0+self.freudBonus)
		--displayBar()
	end
end

--display madness bar
function displayBar()
	if (self.madnessCount >= 50) then
		world.sendEntityMessage(self.playerId,"setBar","madnessBar",self.madnessPercent,self.barColor)
	else
		world.sendEntityMessage(self.playerId,"removeBar","madnessBar")
	end
end

function checkMadnessArt()
	local greatMadnessArt={"thehuntpainting","demiurgepainting","elderhugepainting"}
	local hasPainting=false
	for _,art in pairs(greatMadnessArt) do
		if player.hasItem(art) then
			player.addCurrency("fumadnessresource", 5)
			if math.random(2) == 5 then
			  player.radioMessage("crazycarry")
		    end
			hasPainting=true
			break
		end
	end
	
	local madnessArt={"dreamspainting","fleshpainting","homepainting","hordepainting","nightmarepainting","theexpansepainting","thefishpainting","thepalancepainting","theroompainting","thingsinthedarkpainting","elderpainting1","elderpainting2","elderpainting3","elderpainting4","elderpainting5","elderpainting6","elderpainting7","elderpainting8","elderpainting9","elderpainting10","elderpainting11"}
	for _,art in pairs(madnessArt) do
		if player.hasItem(art) then
			player.addCurrency("fumadnessresource", 2)
			if math.random(2) == 5 then
			  player.radioMessage("crazycarry")
		    end
			hasPainting=true
			break
		end
	end
	self.paintTimer = 20.0 + (status.stat("mentalProtection") * 25)
	if hasPainting then
		status.addEphemeralEffect("madnesspaintingindicator",self.paintTimer)
	end
	
end

function isWeirdStuff(duration)
	local weirdStuff={"faceskin","greghead","greggnog","babyheadonastick","meatpickle"}
	for _,art in pairs(weirdStuff) do
		if player.hasItem(art) then
			player.addCurrency("fumadnessresource", 2)
			status.addEphemeralEffect("madnessfoodindicator",duration)
			if math.random(2) == 5 then
			  player.radioMessage("crazycarry")
		    end
			break
		end
	end
end

function uninit()
	status.setPersistentEffects("madnessEffectsMain",{})
	world.sendEntityMessage(self.playerId,"removeBar","madnessBar")
end