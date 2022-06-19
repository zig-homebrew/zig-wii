const std = @import("std");
const builtin = @import("builtin");

const emulator = "dolphin-emu";
const flags = .{"-logc"};
const devkitpro = "/opt/devkitpro";

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();

    const obj = b.addObject("zig-wii", "src/main.zig");
    obj.setOutputDir("zig-out");
    obj.linkLibC();
    obj.setLibCFile(std.build.FileSource{ .path = "libc.txt" });
    obj.addIncludeDir(devkitpro ++ "/libogc/include");
    obj.addIncludeDir(devkitpro ++ "/portlibs/wii/include");
    obj.setTarget(.{
        .cpu_arch = .powerpc,
        .os_tag = .freestanding,
        .abi = .eabi,
        .cpu_model = .{ .explicit = &std.Target.powerpc.cpu.@"750" },
        .cpu_features_add = std.Target.powerpc.featureSet(&.{.hard_float}),
    });
    obj.setBuildMode(mode);

    const extension = if (builtin.target.os.tag == .windows) ".exe" else "";
    const elf = b.addSystemCommand(&(.{
        devkitpro ++ "/devkitPPC/bin/powerpc-eabi-gcc" ++ extension,
        "-g",
        "-DGEKKO",
        "-mrvl",
        "-mcpu=750",
        "-meabi",
        "-mhard-float",
        "-Wl,-Map,zig-out/zig-wii.map",
        "zig-out/zig-wii.o",
        "-L" ++ devkitpro ++ "/libogc/lib/cube",
        "-L" ++ devkitpro ++ "/portlibs/wii/lib",
    } ++ flags ++ .{
        "-o",
        "zig-out/zig-wii.elf",
    }));

    const dol = b.addSystemCommand(&.{
        devkitpro ++ "/tools/bin/elf2dol",
        "zig-out/zig-wii.elf",
        "zig-out/zig-wii.dol",
    });

    b.default_step.dependOn(&dol.step);
    dol.step.dependOn(&elf.step);
    elf.step.dependOn(&obj.step);

    const run_step = b.step("run", "Run in Dolphin");
    const dolphin = b.addSystemCommand(&.{ emulator, "-d", "-a", "LLE", "-e", "zig-out/zig-wii.elf" });
    run_step.dependOn(&elf.step);
    run_step.dependOn(&dolphin.step);
}
