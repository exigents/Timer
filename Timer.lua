--[[
SIMPLE STATEFUL TIMER
----------------------

INFORMATION:
    A simple & stateful timer that can be used to run certain functions after a certain amount of time.  It can be paused, resumed, and reset.
    
	
----------------------
DOCUMENTATION:
	
Constructor:
	Timer.new(duration: number, Loops: boolean, TimesToLoop: number, callback: function) -> Timer Creates a new timer with the given duration and callback.
													   										The timer is not started until :start() is called.
		ARG				TYPE			DESCRIPTION
	[duration]     :  number    -->  The amount of time in seconds the timer will be.
	[Loops]        :  boolean   -->  Whether or not the timer should loop.
	[TimesToLoop]  :  number    -->  The amount of times the timer should loop. If Loops is false, this value will be ignored.
	[callback]     :  function  -->  A callback function that will be called when the timer finishes.
	
Methods: 				     ARGS	   RETURN		           DESCRIPTION
	Timer:start()   	  ->  nil  |    nil       |  Starts the timer.
	Timer:stop()     	  ->  nil  |    nil 	  |  Stops the timer. Calls the callback function early.
	Timer:reset()   	  ->  nil  |    nil 	  |  Resets the timer to its original duration and stops it if it was running.
	Timer:pause()   	  ->  nil  |    nil 	  |  Pauses the timer at its current time.
	Timer:resume()   	  ->  nil  |    nil 	  |  Resumes the timer at the time it was paused.
	Timer:set()   	 	  ->  num  |    nil 	  |  Sets the timer to the given number. Will do nothing if no number is passed through.
	Timer:add()  		  ->  num  |    nil 	  |  Adds the given number to the timer.
	Timer:sub()	  		  ->  num  |    nil 	  |  Subtracts the given number from the timer.
	Timer:pauseFor()	  ->  num  |    nil       |  Pauses the timer for the given amount of seconds.
	Timer:toDateString()  ->  num  |    string    |  Returns the time string for the given number in seconds.
	Timer:getState()	  ->  nil  |    string    |  Returns the state of the timer. States: Running, Stopped, Paused
	
Properties:              VALUE			DESCRIPTION
	Timer.Duration   :  number   |  The duration of the timer in seconds. Can be changed at any time, but will not affect a running timer until reset.
	Timer.State      :  boolean  |  Whether the timer is running or not.
	Timer.Looped     :  boolean  |  Whether the timer loops or not.
	Timer.LoopTimes  :  Number   |  The amount of times the timer will loop before it ends.
	
Signals:				 TYPE	    RETURN			DESCRIPTION
	Timer.Started    :  Signal  -->  nil   |  Fires when the timer starts.
	Timer.Stopped    :  Signal  -->  nil   |  Fires when the timer stops.
	Timer.Paused     :  Signal  -->  nil   |  Fires when the timer is paused.
	Timer.Resumed    :  Signal  -->  nil   |  Fires when the timer is resumed from a pause state.
	Timer.Completed  :  Signal  -->  nil   |  Fires when the timer completes its duration.
	Timer.Tick	     :  Signal  -->  num   |  Fires every second the timer counts down. Returns the time remaining on the timer. 
	Timer.DidLoop    :  Signal  -->  num   |  Fires every time the timer does a loop. Returns the amount of times it has looped.

Author:
	@exigents
	08 / 01 / 2023

]]--



--> DEPENDENCIES
local Packages = script.Parent.Parent.Public
local class = require(Packages:WaitForChild("class"))
local signal = require(Packages:WaitForChild("signal"))

--> SERVICES
local RunService = game:GetService("RunService")

--> CLASS DEFINE
local Timer = class("timer")

--> Class Functions

function Timer:__init(duration: number, Loops: boolean, LoopTimes: number, _callBack: () -> ())
	--> Variables
	self.OriginalDuration = duration
	self.Duration = duration
	self.callBack = _callBack
	self.State = false
	self.isPaused = false
	self.Loops = type(Loops) == "boolean" and Loops or false
	self.LoopTimes = tonumber(LoopTimes) or (self.Loops and math.huge or 0)
	
	if self.LoopTimes == 0 and self.Loops == true then
		self.Loops = false
	end
	
	--> Signals
	self.Started = signal.new()
	self.Stopped = signal.new()
	self.Paused = signal.new()
	self.Resumed = signal.new()
	self.Completed = signal.new()
	self.Tick = signal.new()
	self.DidLoop = signal.new()
	
	--> Connections
	self.TimerConnection = nil
end

function Timer:start()
	if self.TimerConnection ~= nil then return end
	
	self.State = true
	
	self.Started:Fire()
	
	local nextTick = time() + 1
	local TimesLooped = 0
	
	self.TimerConnection = RunService.Heartbeat:Connect(function(dt)
		if self.Duration <= 0 then
			if self.Loops == false then
				self.Duration = 0
				self.State = false
				self.callBack()
				self.Completed:Fire()
				self.TimerConnection:Disconnect()
			else
				if TimesLooped < self.LoopTimes then
					self.Duration = self.OriginalDuration
					self.callBack()
					self.DidLoop:Fire(TimesLooped)
					TimesLooped += 1
				elseif TimesLooped >= self.LoopTimes then
					self.Duration = 0
					self.State = false
					self.callBack()
					self.Completed:Fire()
					self.TimerConnection:Disconnect()
				end
			end
		end
		if self.State == true then
			if time() >= nextTick then
				self.Duration -= 1
				self.Tick:Fire(self.Duration)
				nextTick = time() + 1
			end
		elseif self.State == false then
			task.wait()
		end
	end)
end

function Timer:toDateString(timeInSeconds: number)
	local n = tonumber(timeInSeconds) or 0
	
	local hours = math.floor(n / 3600)
	local minutes = math.floor((n % 3600) / 60)
	local seconds = n % 60 

	if hours >= 1 then
		return string.format("%dh %dm %ds", hours, minutes, seconds)
	elseif minutes >= 1 then
		return string.format("%dm %ds", minutes, seconds)
	elseif seconds >= 1 then
		return string.format("%ds",seconds)
	end
end

function Timer:pause()
	self.State = false
	self.isPaused = true
	self.Paused:Fire()
end

function Timer:pauseFor(num: number)
	if not tonumber(num) then return end
	if num <= 0 then return end
	
	if self.State == true then
		self.State = false
		self.isPaused = true
		self.Paused:Fire()
		
		task.wait(num)
		
		self.State = true
		self.Resumed:Fire()
		self.isPaused = false
	end
end

function Timer:resume()
	self.State = true
	self.isPaused = false
	self.Resumed:Fire()
end

function Timer:stop()
	self.State = false
	self.TimerConnection:Disconnect()
	
	self.callBack()
	self.Stopped:Fire()
end

function Timer:reset()
	self.Duration = self.OriginalDuration
end

function Timer:getState()
	local State = self.State
	local Paused = State.isPaused
	
	if State == true then
		return "Running"
	elseif State == false and Paused == false then
		return "Stopped"
	elseif State == false and Paused == true then
		return "Paused"
	end
end

function Timer:set(number: number)
	if not tonumber(number) then return end
	self.Duration = number
end

function Timer:add(number: number)
	if not tonumber(number) then return end
	self.Duration += number
end

function Timer:sub(number: number)
	if not tonumber(number) then return end
	if self.Duration - number < 0 then
		local extra = self.Duration - number
		number += extra
	end
	
	self.Duration -= number
end

--> Return Class
return Timer
