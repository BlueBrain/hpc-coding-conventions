#!/usr/bin/env python3

from collections import namedtuple
import glob
import os
import os.path as osp

import jinja2
import yaml


CONVENTION_ATTRS = [
    'title',
    'description',
    'clang_format_key',
    'clang_format_value',
]

class Convention(namedtuple('Convention', CONVENTION_ATTRS)):
    @staticmethod
    def from_file(clang_format, file):
        print(file)

        with open(file) as istr:
            step = 'title'
            attrs = {'description': ''}
            for line in istr:
                if step == 'title':
                    assert line.startswith('// ')
                    attrs['title'] = line[3:].rstrip()
                    step = 'desc'
                elif step == 'desc':
                    if line.startswith('// '):
                        attrs['description'] += line[3:].rstrip()
                    elif line.strip():
                        raise Exception('Expected empty line after description')
                    else:
                        step = 'before_snippet'
                        print(step, line)
                elif step == 'before_snippet':
                    if line.strip():
                        step = 'snippet'
                if step == 'snippet':
                    attrs.setdefault('snippet', '')
                    attrs['snippet'] += line
        basename = osp.splitext(osp.basename(file))[0]
        attrs['clang_format_key'] = basename
        attrs['clang_format_value'] = clang_format[attrs['clang_format_key']]
        return Convention(**attrs)


def load_conventions(path):
    with open('.clang-format') as istr:
        clang_format = yaml.load(istr)
    assert osp.isdir(path)
    for file in glob.glob(path + os.sep + '*.cpp'):
        yield Convention.from_file(clang_format, file)


def build_documentation(template_str, ostr, **kwargs):
    template = jinja2.Template(template_str)
    template.stream(**kwargs).dump(ostr)


def main():
    with open('code-formatting.md.jinja') as istr:
        template_str = istr.read()
    with open('code-formatting.md', 'w') as ostr:
        build_documentation(
            template_str,
            ostr,
            conventions=list(load_conventions('code-formatting'))
        )


if __name__ == '__main__':
    main()
