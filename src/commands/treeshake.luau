local output = require("../libs/output");
local package_helper = require("../libs/package_helper");

return function()
    output.write("Treeshaking project");
    package_helper.treeshake();    
end