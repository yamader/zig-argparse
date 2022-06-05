const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const ArrayList = std.ArrayList;

const ParseError = error{
    MismatchArgumentsNumber,
    UnknownArgument,
};

fn ParseResult(comptime T: type) type {
    return struct {
        result: T,
        operands: ArrayList([]const u8),
    };
}

fn baseType(comptime T: type) type {
    const info = @typeInfo(T);
    return switch (info) {
        .Optional => info.Optional.child,
        else => T,
    };
}

fn knownType(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .Bool, .Int, .Pointer, .Array => true,
        else => false,
    };
}

pub fn parse(comptime T: type, comptime allocator: mem.Allocator) (ParseError || mem.Allocator.Error)!ParseResult(T) {
    const info = @typeInfo(T).Struct;

    // validate
    comptime for (info.fields) |field| if (!knownType(baseType(field.field_type))) {
        @compileError("unknown argument type");
    };

    // variables
    var argi = std.process.args();
    var result: T = undefined;
    var operands = ArrayList([]const u8).init(allocator);

    // required arguments
    comptime var reqArgsNum = 0;
    comptime for (info.fields) |field| if (knownType(field.field_type)) {
        reqArgsNum += 1;
    };
    comptime var reqArgs: [reqArgsNum][]const u8 = undefined;
    comptime for (info.fields) |field, i| if (knownType(field.field_type)) {
        reqArgs[i] = field.name;
    };

    // parse
    var reqArgsI: usize = 0;
    while (argi.next()) |arg| {

        // separator
        if (mem.eql(u8, arg, "--")) {
            while (argi.next()) |operand| {
                if (reqArgsI < reqArgs.len) {
                    const name = reqArgs[reqArgsI];
                    _ = name;
                    switch (@typeInfo(operand)) {
                        .Bool => {},
                        .Int => {},
                        .Pointer => {},
                        .Array => {},
                        else => unreachable,
                    }
                    reqArgsI += 1;
                } else {
                    try operands.append(operand);
                }
            }
            if (reqArgsI < reqArgs.len) {
                return ParseError.MismatchArgumentsNumber;
            }
            break;
        }

        // long options
        if (mem.startsWith(u8, arg, "--")) {
            const name = arg[2..];
            parseArg: {
                inline for (info.fields) |field| if (mem.eql(u8, name, field.name)) {
                    comptime switch (@typeInfo(baseType(field.field_type))) {
                        .Bool => {
                            @field(result, field.name) = true;
                            break :parseArg;
                        },
                        .Int => {
                            break :parseArg;
                        },
                        .Pointer => {
                            break :parseArg;
                        },
                        .Array => {
                            break :parseArg;
                        },
                        else => unreachable,
                    };
                };
                return ParseError.UnknownArgument;
            }
            continue;
        }

        // short options
        if (mem.startsWith(u8, arg, "-")) {
            const name = arg[1..];
            parseShortArg: {
                if (false) {
                    const shorthands = @typeInfo(@TypeOf(T.shorthand)).Struct;
                    inline for (shorthands.fields) |field| if (mem.eql(u8, name, field.name)) {
                        comptime switch (@typeInfo(baseType(field.field_type))) {
                            .Bool => {
                                break :parseShortArg;
                            },
                            .Int => {
                                break :parseShortArg;
                            },
                            .Pointer => {
                                break :parseShortArg;
                            },
                            .Array => {
                                break :parseShortArg;
                            },
                            else => unreachable,
                        };
                    };
                }
                return ParseError.UnknownArgument;
            }
            continue;
        }

        if (reqArgsI < reqArgs.len) {
            const name = reqArgs[reqArgsI];
            _ = name;
            switch (@typeInfo(arg)) {
                .Bool => {},
                .Int => {},
                .Pointer => {},
                .Array => {},
                else => unreachable,
            }
            reqArgsI += 1;
        } else {
            try operands.append(arg);
        }
    }
    if (reqArgsI < reqArgs.len) {
        return ParseError.MismatchArgumentsNumber;
    }

    return ParseResult(T){
        .result = result,
        .operands = operands,
    };
}
