/*
Copyright (c) 2014 Martin Cejp
Copyright (c) 2014 Timur Gafarov 

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module dlib.filesystem.functions;

import dlib.filesystem.filesystem;

import std.range;

private ReadOnlyFileSystem rofs;
private FileSystem fs;

static this() {
    // decouple dependency from the rest of this module
    import dlib.filesystem.localfilesystem;
    
    setFileSystem(new LocalFileSystem);
}

void setFileSystem(FileSystem fs_) {
    rofs = fs_;
    fs = fs_;
}

void setReadOnlyFileSystem(ReadOnlyFileSystem rofs_) {
    rofs = rofs_;
    fs = null;
}

// ReadOnlyFileSystem

bool stat(string filename, out FileStat stat) {
    return rofs.stat(filename, stat);
}

InputStream openForInput(string filename) {
    return rofs.openForInput(filename);
}

Directory openDir(string path) {
    return rofs.openDir(path);
}

InputRange!DirEntry findFiles(string baseDir, bool recursive) {
    return rofs.findFiles(baseDir, recursive);
}

// FileSystem

OutputStream openForOutput(string filename, uint creationFlags) {
    return fs.openForOutput(filename, creationFlags);
}

IOStream openForIO(string filename, uint creationFlags) {
    return fs.openForIO(filename, creationFlags);
}

bool createDir(string path, bool recursive) {
    return fs.createDir(path, recursive);
}

bool move(string path, string newPath) {
    return fs.move(path, newPath);
}

bool remove(string path, bool recursive) {
    return fs.remove(path, recursive);
}

unittest {
    // TODO: test >4GiB files
    
    import std.algorithm;
    import std.conv;
    import std.regex;
    import std.stdio;
    
    alias remove = dlib.filesystem.functions.remove;
    
    remove("tests", true);
    
    assert(openDir("tests") is null);
    
    assert(createDir("tests/test_data/main", true));
    
    void printStat(string filename) {
        FileStat stat_;
        assert(stat(filename, stat_));
        
        writef("  - '%s'\t", filename);
        
        if (stat_.isFile)
            writefln("%u", stat_.sizeInBytes);
        else if (stat_.isDirectory)
            writefln("DIR");
        
        writefln("      created: %s", to!string(stat_.creationTimestamp));
        writefln("      modified: %s", to!string(stat_.modificationTimestamp));
    }
    
    writeln("File stats:");
    printStat("package.json");
    printStat("dlib/core");     // make sure slashes work on Windows
    writeln();
    
    enum dir = "dlib/filesystem";
    writefln("Listing files in %s:", dir);
    
    auto d = openDir(dir);
    
    try {
        foreach (entry; d.contents) {
            if (entry.isFile)
                writeln("    ", entry.name);
        }
    }
    finally {
        d.close();
    }
    
    writeln();
    
    writeln("Listing files mathing the pattern dlib/core/*.d:");

    foreach (entry; findFiles("", true)
            .filter!(entry => entry.isFile)
            .filter!(entry => !matchFirst(entry.name, `^dlib/core/.*\.d$`).empty)
        ) {
        FileStat stat_;
        assert(stat(entry.name, stat_));        // make sure we're getting the expected path
        
        writefln("    %s: %u bytes", entry.name, stat_.sizeInBytes);
    }

    writeln();

    //
    OutputStream outp = openForOutput("tests/test_data/main/hello_world.txt", FileSystem.create | FileSystem.truncate);
    assert(outp);
    
    try {
        assert(outp.writeArray("Hello, World!\n"));
    }
    finally {
        outp.close();
    }
    
    //
    InputStream inp = openForInput("tests/test_data/main/hello_world.txt");
    assert(inp);
    
    try {
        while (inp.readable) {
            char buffer[1];
            
            auto have = inp.readBytes(buffer.ptr, buffer.length);
            std.stdio.write(buffer[0..have]);
        }
    }
    finally {
        inp.close();
    }

    writeln();
}
