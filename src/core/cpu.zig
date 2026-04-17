const std = @import("std");
const log = std.log.scoped(.cpu);

const config = struct {
    const trace_cpu = false;
    const break_on_undefined = true;
};
