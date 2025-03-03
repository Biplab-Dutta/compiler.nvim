--- C language actions

local M = {}

--- Frontend - options displayed on telescope
M.options = {
  { text = "Build and run program", value = "option1" },
  { text = "Build program", value = "option2" },
  { text = "Run program", value = "option3" },
  { text = "Build solution", value = "option4" },
}

function M.getFileNameWithoutExtension(path)
  -- Use regex to capture the part of the path after the last "/" and before the last "."
  return string.match(path, "([^/]+)%.%w+$")
end

--- Backend - overseer tasks performed on option selected
function M.action(selected_option)
  local utils = require("compiler.utils")
  local overseer = require("overseer")
  local entry_point = vim.fn.expand("%:p")
  local files = entry_point
  local output_dir = utils.os_path(vim.fn.getcwd())
  local output = utils.os_path(
    vim.fn.getcwd() .. M.getFileNameWithoutExtension(entry_point)
  )
  local arguments = ""
  local final_message = "--task finished--"

  if selected_option == "option1" then
    local task = overseer.new_task({
      name = "- C compiler",
      strategy = {
        "orchestrator",
        tasks = {
          {
            name = '- Build & run program → "' .. entry_point .. '"',
            cmd = "gcc "
              .. files
              .. ' -o "'
              .. output
              .. '" '
              .. arguments -- compile
              .. ' && "'
              .. output
              .. '"' -- run
              .. ' && echo "'
              .. entry_point
              .. '"' -- echo
              .. ' && echo "'
              .. final_message
              .. '"',
            components = { "default_extended" },
          },
        },
      },
    })
    task:start()
  elseif selected_option == "option2" then
    local task = overseer.new_task({
      name = "- C compiler",
      strategy = {
        "orchestrator",
        tasks = {
          {
            name = '- Build program → "' .. entry_point .. '"',

            cmd = "gcc "
              .. files
              .. ' -o "'
              .. output
              .. '" '
              .. arguments -- compile
              .. ' && echo "'
              .. entry_point
              .. '"' -- echo
              .. ' && echo "'
              .. final_message
              .. '"',
            components = { "default_extended" },
          },
        },
      },
    })
    task:start()
  elseif selected_option == "option3" then
    local task = overseer.new_task({
      name = "- C compiler",
      strategy = {
        "orchestrator",
        tasks = {
          {
            name = '- Run program → "' .. output .. '"',
            cmd = '"'
              .. output
              .. '"' -- run
              .. ' && echo "'
              .. output
              .. '"' -- echo
              .. ' && echo "'
              .. final_message
              .. '"',
            components = { "default_extended" },
          },
        },
      },
    })
    task:start()
  elseif selected_option == "option4" then
    local entry_points
    local task = {}
    local tasks = {}
    local executables = {}

    -- if .solution file exists in working dir
    local solution_file = utils.get_solution_file()
    if solution_file then
      local config = utils.parse_solution_file(solution_file)

      for entry, variables in pairs(config) do
        if entry == "executables" then goto continue end
        entry_point = utils.os_path(variables.entry_point)
        files = utils.find_files_to_compile(entry_point, "*.c")
        output = utils.os_path(variables.output)
        output_dir = utils.os_path(output:match("^(.-[/\\])[^/\\]*$"))
        arguments = variables.arguments or arguments -- optional
        task = {
          name = '- Build program → "' .. entry_point .. '"',
          cmd = "gcc "
            .. files
            .. ' -o "'
            .. output
            .. '" '
            .. arguments -- compile
            .. ' && echo "'
            .. entry_point
            .. '"' -- echo
            .. ' && echo "'
            .. final_message
            .. '"',
          components = { "default_extended" },
        }
        table.insert(tasks, task) -- store all the tasks we've created
        ::continue::
      end

      local solution_executables = config["executables"]
      if solution_executables then
        for entry, executable in pairs(solution_executables) do
          executable = utils.os_path(executable, true)
          task = {
            name = "- Run program → " .. executable,
            cmd = executable -- run
              .. " && echo "
              .. executable -- echo
              .. ' && echo "'
              .. final_message
              .. '"',
            components = { "default_extended" },
          }
          table.insert(executables, task) -- store all the executables we've created
        end
      end

      task = overseer.new_task({
        name = "- C compiler",
        strategy = {
          "orchestrator",
          tasks = {
            tasks, -- Build all the programs in the solution in parallel
            executables, -- Then run the solution executable(s)
          },
        },
      })
      task:start()
    else -- If no .solution file
      -- Create a list of all entry point files in the working directory
      entry_points = utils.find_files(vim.fn.getcwd(), "main.c")

      for _, entry_point in ipairs(entry_points) do
        entry_point = utils.os_path(entry_point)
        files = utils.find_files_to_compile(entry_point, "*.c")
        output_dir =
          utils.os_path(entry_point:match("^(.-[/\\])[^/\\]*$") .. "bin") -- entry_point/bin
        output = utils.os_path(output_dir .. "/program") -- entry_point/bin/program
        task = {
          name = '- Build program → "' .. entry_point .. '"',
          cmd = 'rm -f "'
            .. output
            .. '" || true' -- clean
            .. ' && mkdir -p "'
            .. output_dir
            .. '"' -- mkdir
            .. " && gcc "
            .. files
            .. ' -o "'
            .. output
            .. '" '
            .. arguments -- compile
            .. ' && echo "'
            .. entry_point
            .. '"' -- echo
            .. ' && echo "'
            .. final_message
            .. '"',
          components = { "default_extended" },
        }
        table.insert(tasks, task) -- store all the tasks we've created
      end

      task = overseer.new_task({ -- run all tasks we've created in parallel
        name = "- C compiler",
        strategy = { "orchestrator", tasks = tasks },
      })
      task:start()
    end
  end
end

return M
