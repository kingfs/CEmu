/*
 * Autotester CLI
 * (C) Adrien 'Adriweb' Bertrand
 * Part of the CEmu project
 * License: GPLv3
 */

#include <atomic>
#include <string>
#include <vector>
#include <fstream>
#include <iostream>
#include <thread>
#include <chrono>
#include <cstdarg>
#include <cstring>

#if defined(WIN32) || defined(_WIN32) || defined(__WIN32) && !defined(__CYGWIN__)
  #include <direct.h>
  #define chdir _chdir
#else
  #include <unistd.h>
#endif

#include "autotester.h"

std::atomic<bool> do_transfers;
std::atomic<bool> transfers_done;
std::atomic<bool> transfers_err;

/* As expected by the core */
extern "C"
{
    auto lastTime = std::chrono::steady_clock::now();

    void gui_do_stuff(void)
    {
        if (!transfers_done && do_transfers)
        {
            if (!autotester::sendFilesForTest())
            {
                transfers_err = true;
            }
            transfers_done = true;
        }
    }

    void gui_console_clear() {}
    void gui_console_printf(const char *format, ...) {}
    void gui_console_err_printf(const char *format, ...) {}

    void gui_throttle()
    {
        auto interval  = std::chrono::duration_cast<std::chrono::steady_clock::duration>(std::chrono::duration<int, std::ratio<1, 60 * 1000000>>(1000000));

        auto cur_time  = std::chrono::steady_clock::now(),
             next_time = lastTime + interval;

        if (cur_time < next_time)
        {
            lastTime = next_time;
            std::this_thread::sleep_until(next_time);
        } else {
            lastTime = cur_time;
            std::this_thread::yield();
        }
    }
}

int main(int argc, char* argv[])
{
    // Used if the coreThread has been started (need to exit properly ; uses gotos)
    int retVal = 0;

    if (argc < 2)
    {
        std::cerr << "[Error] Needs a path argument, the test config JSON file" << std::endl;
        return -1;
    }

    if (strcmp(argv[1], "-d") == 0)
    {
        autotester::debugMode = true;
        argv++;
    } else {
        autotester::debugMode = false;
    }

    do_transfers   = false;
    transfers_done = false;
    transfers_err  = false;

    const std::string jsonPath(argv[1]);
    std::string jsonContents;
    std::ifstream ifs(jsonPath);
    if (ifs.good())
    {
        std::getline(ifs, jsonContents, '\0');
        if (!ifs.eof()) {
            std::cerr << "[Error] Couldn't read JSON file" << std::endl;
            return -1;
        }
    } else {
        std::cerr << "[Error] Couldn't open JSON file at provided path" << std::endl;
        return -1;
    }

    // Go to the json file's dir to allow relative paths from there
    if (chdir(jsonPath.substr(0, jsonPath.find_last_of("/\\")).c_str())) {
        std::cerr << "[Error] Couldn't change directory path" << std::endl;
        return -1;
    }

    if (autotester::loadJSONConfig(jsonContents))
    {
        std::cout << jsonPath << " loaded and verified. " << autotester::config.hashes.size() << " unique tests found." << std::endl;
    } else {
        std::cerr << "[Error] See the test config file format and make sure values are correct" << std::endl;
        return -1;
    }

    /* Someone with better multithreading coding experience should probaly re-do this stuff correctly,
     * i.e. actually wait until the core is ready to do stuff, instead of blinding doing sleeps, etc.
     * Things like std::condition_variable should help, IIRC */
    std::thread coreThread;
    if (cemucore::EMU_STATE_VALID == cemucore::emu_load(cemucore::EMU_DATA_ROM, autotester::config.rom.c_str()))
    {
        coreThread = std::thread(&cemucore::emu_loop);
    } else {
        std::cerr << "[Error] Couldn't start emulation!" << std::endl;
        return -1;
    }

    std::this_thread::sleep_for(std::chrono::milliseconds(1000));

    // Clear home screen
    autotester::sendKey(0x09);
    std::this_thread::sleep_for(std::chrono::milliseconds(300));

    do_transfers = !autotester::config.transfer_files.empty();

    if (do_transfers)
    {
        while (!transfers_done) {
            // wait for the emu thread to finish that.
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
        do_transfers = false;
        if (transfers_err)
        {
            std::cerr << "[Error] Error while in sendFilesForTest!" << std::endl;
            retVal = -1;
            goto cleanExit;
        }
    }

    std::this_thread::sleep_for(std::chrono::milliseconds(500));

    // Follow the sequence
    if (!autotester::doTestSequence())
    {
        std::cerr << "[Error] Error while in doTestSequence!" << std::endl;
        retVal = -1;
        goto cleanExit;
        // This is useless here since cleanExit is right after,
        // but in case some other things are added in between at some point...
    }

cleanExit:
    cemucore::emu_exit();
    coreThread.join();

    // If no JSON/program/misc. error, return the hash failure count.
    if (retVal == 0)
    {
        const char* status = autotester::hashesFailed == 0 ? "[Autotest passed]" : "[Autotest failed]";
        std::cout << status << " Out of " << autotester::hashesTested << " tests attempted, "
                  << autotester::hashesPassed << " passed, and " << autotester::hashesFailed << " failed.\n" << std::endl;

        return autotester::hashesFailed;
    }

    return retVal;
}
