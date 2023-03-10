local sides = require "sides"
local robot = require "robot"
local cmp = require "component"
local term = require "term"
local inv = cmp.inventory_controller

term.clear()
robot.select(1)

local msg = {
    robot = "[Робот]: ",
    error = "[Ошибка]: ",
    system = "[Система]: "
}

print(msg.system .. "Инициализация скрипта...")

-- Это редактировать можно :3
local USER_CONFIG = {
    -- Минимальный порог использования энергии для инструмента
    MIN_ENERGY = 60, -- % (от 1 до 100)
    -- Сон, пока инструмент заряжается
    TIMEOUT = 10,
    -- Кол-во шагов, после которых робот сделает короткую паузу
    -- для очистки инвентаря (оптимальное - по умолчанию)
    CLEAR_STEP = 50,
    -- Кол-во существ в инвентаре, при достижении кол-ва которых
    -- робот начнёт их спавнить
    SPAWN_LIMIT = 5,
}
-- Это редактировать нельзя.
-- Редактирование может привести к некорректной работе скрипта

local _CONFIG = {
    SWORD_NAME = nil,
    CURRENT_STEP = 0,
    INVENTORY_SIZE = robot.inventorySize(),
    MOB_NAME = "DraconicEvolution:mobSoul",
    MOB_SLOT = nil,
    DISABLED = false
}

local helper = {
    detect_spawn = function()
        local mob_slot = inv.getStackInInternalSlot(_CONFIG.MOB_SLOT)

        if mob_slot ~= nil and mob_slot.name == _CONFIG.MOB_SLOT then
            return _CONFIG.MOB_SLOT
        end

        for i = 1, _CONFIG.INVENTORY_SIZE do
            local item = inv.getStackInInternalSlot(i)

            if item ~= nil and item.name == _CONFIG.MOB_NAME then
                _CONFIG.MOB_SLOT = i
                return i
            end
        end

        return nil
    end
}

local validate = {
    upgrades = function()
        local errors = {}

        if _CONFIG.INVENTORY_SIZE == nil or _CONFIG.INVENTORY_SIZE == 0 then
            errors[1] = "Улучшение \"Инвентарь\""
        end

        if inv == nil then
            errors[2] = "Улучшение \"Контроллер инвентаря\""
        end

        if #errors > 0 then
            print(msg.error .. "Отсутствует: (´･ᴗ･ )")

            for i = 1, #errors do
                print(i .. ". " .. errors[i])
            end

            os.exit()
        end
    end,
    mobs_exist = function()
        local mob_slot = helper.detect_spawn()

        if mob_slot ~= nil then
            print(msg.robot .. "обнаружен моб в " .. mob_slot .. " слоте.")
        end
    end,
    sword_exist = function()
        local sword = inv.getStackInInternalSlot(1)

        if sword == nil then
            print(msg.robot .. "Разместите меч в 1-ый слот моего инвентаря.")
            os.exit()
        end

        _CONFIG.SWORD_NAME = sword.label
        inv.equip()
        print(msg.robot .. "взял " .. sword.label .. " на вооружение!")
    end,
}

local action = {
    suck = function()
        if not _CONFIG.DISABLED then
            robot.suck()
        end
    end,
    spawn = function()
        if helper.detect_spawn() ~= nil then
            local mob_slot = inv.getStackInInternalSlot(_CONFIG.MOB_SLOT)
            local mob_slot_size = mob_slot.size - 1

            if mob_slot_size <= USER_CONFIG.SPAWN_LIMIT then
                return false
            end

            robot.select(_CONFIG.MOB_SLOT)

            for i = 1, mob_slot_size do
                robot.place(nil, true)
            end

            robot.select(1)
            print(msg.robot .. "заспавнил " .. mob_slot_size .. " мобов")
        end
    end,
    drop = function()
        local counter = 0

        for i = 1, _CONFIG.INVENTORY_SIZE do
            local item = inv.getStackInInternalSlot(i)

            if item == nil or item.name == _CONFIG.MOB_NAME or item.label == _CONFIG.SWORD_NAME then
                goto loop_end
            end

            robot.select(i)
            robot.dropUp()
            counter = counter + 1

            ::loop_end::
        end

        if counter > 0 then
            print(msg.robot .. " сбросил " .. counter .. " предметов.")
        end
    end,
    charge = function()
        robot.select(1)
        inv.equip()

        local sword = inv.getStackInInternalSlot(1)
        local percentage = (sword.energy / sword.maxEnergy) * 100
        
        if sword.label == _CONFIG.SWORD_NAME and percentage > USER_CONFIG.MIN_ENERGY then
            inv.equip()
            return false
        end

        robot.dropDown()
        os.sleep(USER_CONFIG.TIMEOUT)
        robot.suckDown()
        inv.equip()
    end
}

print(msg.system .. "Валидация перед стартом...")

validate.upgrades()
validate.sword_exist()
validate.mobs_exist()

function step_clear()
    action.suck()
    action.drop()
    action.charge()
    action.spawn()
end

step_clear()

print(msg.system .. "Валидация прошла успешно.")
print(msg.robot .. "Приступаю к работе.")

while true do
    robot.swing()
    action.suck()

    _CONFIG.CURRENT_STEP = _CONFIG.CURRENT_STEP + 1

    os.sleep(0.5)

    if _CONFIG.CURRENT_STEP == USER_CONFIG.CLEAR_STEP then
        _CONFIG.DISABLED = true
        step_clear()
        _CONFIG.DISABLED = false
        _CONFIG.CURRENT_STEP = 0
    end
end
