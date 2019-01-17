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
    'snippet'
]


class Convention(namedtuple('Convention', CONVENTION_ATTRS)):
    @staticmethod
    def from_file(clang_format, file):
        attrs = dict(description='', snippet='')

        def is_comment(line):
            return line.startswith('// ')

        with open(file) as istr:
            content = [line.rstrip() for line in istr.readlines()]
        # retrieve title
        assert is_comment(content[0])
        attrs['title'] = content[0].lstrip('// ')
        # retrieve description
        i = 1
        while i < len(content) and is_comment(content[i]):
            attrs['description'] += content[i].lstrip('// ') + '\n'
            i += 1
        # eat empty lines
        while i < len(content) and not content[i]:
            i += 1
        # retrieve code snippet
        while i < len(content):
            if not content[i].lstrip().startswith('// clang-format'):
                attrs['snippet'] += content[i] + '\n'
            i += 1
        basename = osp.splitext(osp.basename(file))[0]
        attrs['clang_format_key'] = basename
        attrs['clang_format_value'] = clang_format[attrs['clang_format_key']]
        return Convention(**attrs)


def load_conventions(path):
    with open('.clang-format') as istr:
        clang_format = yaml.load(istr)
    assert osp.isdir(path)
    for file in sorted(glob.glob(path + os.sep + '*.cpp')):
        yield Convention.from_file(clang_format, file)


def build_documentation(template_str, ostr, **kwargs):
    template = jinja2.Template(template_str)
    template.stream(**kwargs).dump(ostr)


def main():
    with open('formatting.md.jinja') as istr:
        template_str = istr.read()
    with open('formatting.md', 'w') as ostr:
        build_documentation(
            template_str,
            ostr,
            conventions=list(load_conventions('snippets'))
        )


if __name__ == '__main__':
    main()
