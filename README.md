# USE!UMBS
Upper Memory Block Manager for PC/XT/ATs

## Intro

This reporsitory hosts the USE!UMBS Upper Memory Blocks (UMBs) Manager for PC/XT/ATs source code and binaries.

The USE!UMBS.SYS provides interface to manage Upper Memory Blocks and make them available for DOS 5.0 and above. It is mostly useful on systems based on 8086/88, 80188/80186, 80286, and NEC V-series CPUs. Systems based on 386SX and above should use [EMM386](https://en.wikipedia.org/wiki/EMM386) instead.

## Credits

* The original USE!UMBS.SYS code verison was written by Marco van Zwetselaar
* Subsequent modifications were done by Krister Nordvall (Krille at [VCFed Forums](https://forum.vcfed.org/index.php)). Here is the [relevant discussion thread](https://forum.vcfed.org/index.php?threads/loading-dos-high-on-a-xt.32320/).

## Usage information

* [Original README file](README.TXT)
* [Original Documentation](USE!UMBS.TXT)

### Sample Configuration Files

Below is an example of a **CONFIG.SYS** file that loads USE!UMBS.SYS and loads the DOS into UMBs.
Note that the address range argument specified after **USE!UMBS.SYS** should match the UMBs address range available on your system (D000-EFFF in this example).
In addition to USE!UMBS, it also uses [DOSMAX.EXE](DOSMAX21.ZIP) that moves most of the DOS code into UMBs.
Use **DEVICEHIGH** directive to load device drivers into UMBs:

```
FILES=30
BUFFERS=20
DOS=UMB
DEVICE=C:\USE!UMBS.SYS D000-EFFF
DEVICE=C:\DOSMAX.EXE /R+ /N+ /P-
DEVICEHIGH=C:\DOS\SETVER.EXE
```

Below is an example of an **AUTOEXEC.BAT** file.
Use **LH** directive to load drivers and other TSRs into UMBs:

```
@ECHO OFF
SET PATH=C:\DOS
SET TEMP=C:\DOS
LH C:\DOS\MOUSE.COM
LH C:\DOS\DOSKEY.COM
```

## Changes

* v2.5
  * Fixed a bug where finding a bad UMB would lead to registers and the stack not being properly restored on exit.
  * Minor size optimizations.

* v2.4
  * Fixed a bug where half of the WORD terminating the list of UMB ranges could end up after the driver breakpoint.

* v2.3
  * Segment addresses given as parameters are now verified to be in the UMA.
  * UMBs are now verified to be writable (ROM/bad RAM/no RAM will generate an error).
  * Added support for the XTMax (based on work by Matthieu Bucchianeri).
  * Minor size optimizations.

* v2.2
  * UMBs are now initialized to avoid parity errors.
  * Minor size optimizations.

* v2.1 - Initial version from Krister Nordvall
  * Added support for specifying the address range for the UMB, e.g., `DEVICE=USE!UMBS.SYS D000-EFFF`
  * Reduced memory usage

* v2.0 - Original files from Marco van Zwetselaar
  * README is renamed to README.TXT
  * USE!UMBS.DOC is renamed to USE!UMBS.TXT
