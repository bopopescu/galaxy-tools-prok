# filemerge.py - file-level merge handling for Mercurial
#
# Copyright 2006, 2007, 2008 Matt Mackall <mpm@selenic.com>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

from node import short
from i18n import _
import util, simplemerge, match, error
import os, tempfile, re, filecmp

def _toolstr(ui, tool, part, default=""):
    return ui.config("merge-tools", tool + "." + part, default)

def _toolbool(ui, tool, part, default=False):
    return ui.configbool("merge-tools", tool + "." + part, default)

def _toollist(ui, tool, part, default=[]):
    return ui.configlist("merge-tools", tool + "." + part, default)

_internal = ['internal:' + s
             for s in 'fail local other merge prompt dump'.split()]

def _findtool(ui, tool):
    if tool in _internal:
        return tool
    for kn in ("regkey", "regkeyalt"):
        k = _toolstr(ui, tool, kn)
        if not k:
            continue
        p = util.lookupreg(k, _toolstr(ui, tool, "regname"))
        if p:
            p = util.findexe(p + _toolstr(ui, tool, "regappend"))
            if p:
                return p
    exe = _toolstr(ui, tool, "executable", tool)
    return util.findexe(util.expandpath(exe))

def _picktool(repo, ui, path, binary, symlink):
    def check(tool, pat, symlink, binary):
        tmsg = tool
        if pat:
            tmsg += " specified for " + pat
        if not _findtool(ui, tool):
            if pat: # explicitly requested tool deserves a warning
                ui.warn(_("couldn't find merge tool %s\n") % tmsg)
            else: # configured but non-existing tools are more silent
                ui.note(_("couldn't find merge tool %s\n") % tmsg)
        elif symlink and not _toolbool(ui, tool, "symlink"):
            ui.warn(_("tool %s can't handle symlinks\n") % tmsg)
        elif binary and not _toolbool(ui, tool, "binary"):
            ui.warn(_("tool %s can't handle binary\n") % tmsg)
        elif not util.gui() and _toolbool(ui, tool, "gui"):
            ui.warn(_("tool %s requires a GUI\n") % tmsg)
        else:
            return True
        return False

    # forcemerge comes from command line arguments, highest priority
    force = ui.config('ui', 'forcemerge')
    if force:
        toolpath = _findtool(ui, force)
        if toolpath:
            return (force, '"' + toolpath + '"')
        else:
            # mimic HGMERGE if given tool not found
            return (force, force)

    # HGMERGE takes next precedence
    hgmerge = os.environ.get("HGMERGE")
    if hgmerge:
        return (hgmerge, hgmerge)

    # then patterns
    for pat, tool in ui.configitems("merge-patterns"):
        mf = match.match(repo.root, '', [pat])
        if mf(path) and check(tool, pat, symlink, False):
            toolpath = _findtool(ui, tool)
            return (tool, '"' + toolpath + '"')

    # then merge tools
    tools = {}
    for k, v in ui.configitems("merge-tools"):
        t = k.split('.')[0]
        if t not in tools:
            tools[t] = int(_toolstr(ui, t, "priority", "0"))
    names = tools.keys()
    tools = sorted([(-p, t) for t, p in tools.items()])
    uimerge = ui.config("ui", "merge")
    if uimerge:
        if uimerge not in names:
            return (uimerge, uimerge)
        tools.insert(0, (None, uimerge)) # highest priority
    tools.append((None, "hgmerge")) # the old default, if found
    for p, t in tools:
        if check(t, None, symlink, binary):
            toolpath = _findtool(ui, t)
            return (t, '"' + toolpath + '"')

    # internal merge or prompt as last resort
    if symlink or binary:
        return "internal:prompt", None
    return "internal:merge", None

def _eoltype(data):
    "Guess the EOL type of a file"
    if '\0' in data: # binary
        return None
    if '\r\n' in data: # Windows
        return '\r\n'
    if '\r' in data: # Old Mac
        return '\r'
    if '\n' in data: # UNIX
        return '\n'
    return None # unknown

def _matcheol(file, origfile):
    "Convert EOL markers in a file to match origfile"
    tostyle = _eoltype(util.readfile(origfile))
    if tostyle:
        data = util.readfile(file)
        style = _eoltype(data)
        if style:
            newdata = data.replace(style, tostyle)
            if newdata != data:
                util.writefile(file, newdata)

def filemerge(repo, mynode, orig, fcd, fco, fca):
    """perform a 3-way merge in the working directory

    mynode = parent node before merge
    orig = original local filename before merge
    fco = other file context
    fca = ancestor file context
    fcd = local file context for current/destination file
    """

    def temp(prefix, ctx):
        pre = "%s~%s." % (os.path.basename(ctx.path()), prefix)
        (fd, name) = tempfile.mkstemp(prefix=pre)
        data = repo.wwritedata(ctx.path(), ctx.data())
        f = os.fdopen(fd, "wb")
        f.write(data)
        f.close()
        return name

    if not fco.cmp(fcd): # files identical?
        return None

    ui = repo.ui
    fd = fcd.path()
    binary = fcd.isbinary() or fco.isbinary() or fca.isbinary()
    symlink = 'l' in fcd.flags() + fco.flags()
    tool, toolpath = _picktool(repo, ui, fd, binary, symlink)
    ui.debug("picked tool '%s' for %s (binary %s symlink %s)\n" %
               (tool, fd, binary, symlink))

    if not tool or tool == 'internal:prompt':
        tool = "internal:local"
        if ui.promptchoice(_(" no tool found to merge %s\n"
                             "keep (l)ocal or take (o)ther?") % fd,
                           (_("&Local"), _("&Other")), 0):
            tool = "internal:other"
    if tool == "internal:local":
        return 0
    if tool == "internal:other":
        repo.wwrite(fd, fco.data(), fco.flags())
        return 0
    if tool == "internal:fail":
        return 1

    # do the actual merge
    a = repo.wjoin(fd)
    b = temp("base", fca)
    c = temp("other", fco)
    out = ""
    back = a + ".orig"
    util.copyfile(a, back)

    if orig != fco.path():
        ui.status(_("merging %s and %s to %s\n") % (orig, fco.path(), fd))
    else:
        ui.status(_("merging %s\n") % fd)

    ui.debug("my %s other %s ancestor %s\n" % (fcd, fco, fca))

    # do we attempt to simplemerge first?
    try:
        premerge = _toolbool(ui, tool, "premerge", not (binary or symlink))
    except error.ConfigError:
        premerge = _toolstr(ui, tool, "premerge").lower()
        valid = 'keep'.split()
        if premerge not in valid:
            _valid = ', '.join(["'" + v + "'" for v in valid])
            raise error.ConfigError(_("%s.premerge not valid "
                                      "('%s' is neither boolean nor %s)") %
                                    (tool, premerge, _valid))

    if premerge:
        r = simplemerge.simplemerge(ui, a, b, c, quiet=True)
        if not r:
            ui.debug(" premerge successful\n")
            os.unlink(back)
            os.unlink(b)
            os.unlink(c)
            return 0
        if premerge != 'keep':
            util.copyfile(back, a) # restore from backup and try again

    env = dict(HG_FILE=fd,
               HG_MY_NODE=short(mynode),
               HG_OTHER_NODE=str(fco.changectx()),
               HG_BASE_NODE=str(fca.changectx()),
               HG_MY_ISLINK='l' in fcd.flags(),
               HG_OTHER_ISLINK='l' in fco.flags(),
               HG_BASE_ISLINK='l' in fca.flags())

    if tool == "internal:merge":
        r = simplemerge.simplemerge(ui, a, b, c, label=['local', 'other'])
    elif tool == 'internal:dump':
        a = repo.wjoin(fd)
        util.copyfile(a, a + ".local")
        repo.wwrite(fd + ".other", fco.data(), fco.flags())
        repo.wwrite(fd + ".base", fca.data(), fca.flags())
        os.unlink(b)
        os.unlink(c)
        return 1 # unresolved
    else:
        args = _toolstr(ui, tool, "args", '$local $base $other')
        if "$output" in args:
            out, a = a, back # read input from backup, write to original
        replace = dict(local=a, base=b, other=c, output=out)
        args = util.interpolate(r'\$', replace, args,
                                lambda s: '"%s"' % util.localpath(s))
        r = util.system(toolpath + ' ' + args, cwd=repo.root, environ=env,
                        out=ui.fout)

    if not r and (_toolbool(ui, tool, "checkconflicts") or
                  'conflicts' in _toollist(ui, tool, "check")):
        if re.search("^(<<<<<<< .*|=======|>>>>>>> .*)$", fcd.data(),
                     re.MULTILINE):
            r = 1

    checked = False
    if 'prompt' in _toollist(ui, tool, "check"):
        checked = True
        if ui.promptchoice(_("was merge of '%s' successful (yn)?") % fd,
                           (_("&Yes"), _("&No")), 1):
            r = 1

    if not r and not checked and (_toolbool(ui, tool, "checkchanged") or
                                  'changed' in _toollist(ui, tool, "check")):
        if filecmp.cmp(repo.wjoin(fd), back):
            if ui.promptchoice(_(" output file %s appears unchanged\n"
                                 "was merge successful (yn)?") % fd,
                               (_("&Yes"), _("&No")), 1):
                r = 1

    if _toolbool(ui, tool, "fixeol"):
        _matcheol(repo.wjoin(fd), back)

    if r:
        if tool == "internal:merge":
            ui.warn(_("merging %s incomplete! "
                      "(edit conflicts, then use 'hg resolve --mark')\n") % fd)
        else:
            ui.warn(_("merging %s failed!\n") % fd)
    else:
        os.unlink(back)

    os.unlink(b)
    os.unlink(c)
    return r
