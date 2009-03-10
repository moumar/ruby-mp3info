#!/usr/bin/python
"""
mp3info fuzzer
"""

MANGLE = "auto"

from fusil.application import Application
from optparse import OptionGroup
from fusil.process.mangle import MangleProcess
from fusil.process.watch import WatchProcess
from fusil.process.stdout import WatchStdout
if MANGLE == "incr":
    from fusil.incr_mangle import IncrMangle as Mp3Mangle
elif MANGLE == "auto":
    from fusil.auto_mangle import AutoMangle as Mp3Mangle
else:
    from fusil.mangle import MangleFile as Mp3Mangle

class Fuzzer(Application):
    USAGE = "%prog [options] audio.mp3"
    NB_ARGUMENTS = 1

    def setupProject(self):
        project = self.project

        orig_filename = self.arguments[0]
        mangle = Mp3Mangle(project, orig_filename)
        mangle.max_size = 50*1024
        if MANGLE == "auto":
            "nothing"
            #mangle.hard_min_op = 1
            #mangle.hard_max_op = 100
        elif MANGLE == "incr":
            from fusil.incr_mangle_op import InverseBit, Increment
            mangle.operations = (InverseBit, Increment)
        else:
            mangle.config.min_op = 0
            #mangle.config.max_op = 10

        process = MangleProcess(project, ['./fuzzer_client.rb', '<mp3>'], '<mp3>', timeout=60.0)
        #process.env.copy('HOME')

        WatchProcess(process) #, exitcode_score=0.50)
        #WatchProcess(process, exitcode_score=0)

        #stdout = WatchStdout(process)
        #stdout.max_nb_line = None
        #stdout.show_matching = True
        #stdout.addRegex(r"The file may be corrupted", -0.50)
        #stdout.addRegex(r"Corrupted ogg", -0.50)
        #stdout.addRegex(r"Could not decode vorbis header packet", -0.50)
    #    stdout.ignoreRegex('^Warning: Could not decode vorbis header packet')
        #stdout.ignoreRegex('^Warning: sequence number gap')
        #stdout.ignoreRegex('^New logical stream.*: type invalid$')

if __name__ == "__main__":
    Fuzzer().main()
