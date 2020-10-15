part of docx_view;

typedef bool Check(XmlElement n);
typedef void OnFound(XmlElement e);

class SdtView {
  final String tag;
  final String name;
  final XmlElement content;
  final XmlElement sdt;
  SdtView(this.tag, this.name, this.content, this.sdt);
  factory SdtView.parse(XmlElement e) {
    if (e.name.local == "sdt") {
      XmlElement sdt = e;
      XmlElement sdtPr = View._findChild(sdt, "sdtPr");
      if (sdtPr != null) {
        XmlElement alias = View._findChild(sdtPr, "alias");
        XmlElement tag = View._findChild(sdtPr, "tag");
        if (alias != null && tag != null) {
          XmlElement content = View._findChild(sdt, "sdtContent");
          if (content != null) {
            XmlAttribute aliasAttr = View._findAttr(alias, "val");
            XmlAttribute tagAttr = View._findAttr(tag, "val");
            if (aliasAttr != null && tagAttr != null) {
              return SdtView(tagAttr.value, aliasAttr.value, content, sdt);
            }
          }
        }
      }
    }
    return null;
  }
}

class View<T extends Content> extends XmlElement {
  Map<String, List<View>> sub;
  final String tag;

  final ViewManager vm;
  View(this.vm, XmlName name,
      [Iterable<XmlAttribute> attributesIterable = const [],
      Iterable<XmlNode> children = const [],
      bool isSelfClosing = true,
      this.tag])
      : super(name, attributesIterable, children, isSelfClosing);

  View createNew(XmlName name,
      [Iterable<XmlAttribute> attributesIterable = const [],
      Iterable<XmlNode> children = const [],
      bool isSelfClosing = true,
      String tag]) {
    return null;
  }

  static traverse(XmlElement node, Check check, OnFound onFound) {
    if (node.children != null && node.children.isNotEmpty) {
      for (var c in node.children) {
        if (c is XmlElement) {
          if (check(c)) {
            onFound(c);
          } else {
            traverse(c, check, onFound);
          }
        }
      }
    }
  }

  static List<View> subViews(XmlElement e) {
    List<View> views = List();
    traverse(e, (test) => test is View, (e) => views.add(e));
    return views;
  }

  List<XmlElement> produce(T c) {
    return [];
  }

  static void replaceWithAll(
      XmlElement elem, List<XmlElement> to, bool clearParents) {
    if (clearParents) {
      for (XmlElement e in to) {
        if (e.parent != null) {
          e.parent.children.remove(e);
        }
      }
    }
    if (elem.parent != null) {
      // Root elem not have parents
      var childs = elem.parent.children;
      var index = childs.indexOf(elem);
      childs.removeAt(index);
      childs.insertAll(index, to);
    }
  }

  static XmlElement _findChild(XmlElement e, String tag) {
    return e.descendants.firstWhere(
        (test) => test is XmlElement && test.name.local == tag,
        orElse: () => null);
  }

  static XmlAttribute _findAttr(XmlElement e, String attr) {
    return e.attributes
        .firstWhere((test) => test.name.local == attr, orElse: () => null);
  }
}

class TextView extends View<TextContent> {
  TextView(ViewManager vm, XmlName name,
      [Iterable<XmlAttribute> attributesIterable = const [],
      Iterable<XmlNode> children = const [],
      bool isSelfClosing = true,
      String tag])
      : super(vm, name, attributesIterable, children, isSelfClosing, tag);

  @override
  List<XmlElement> produce(TextContent c) {
    XmlElement copy = this.accept(vm._copyVisitor);
    final r = findR(copy);
    if (r != null) {
      removeRSiblings(r);
      updateRText(r, c != null ? c.text : '');
    }
    return List.from(copy.children);
  }

  @override
  TextView createNew(XmlName name,
      [Iterable<XmlAttribute> attributesIterable = const [],
      Iterable<XmlNode> children = const [],
      bool isSelfClosing = true,
      String tag]) {
    return TextView(vm, name, attributesIterable, children, isSelfClosing, tag);
  }

  XmlElement findR(XmlElement src) =>
      src.descendants.firstWhere((e) => e is XmlElement && e.name.local == 'r');

  void removeRSiblings(XmlElement sib) {
    final parent = sib.parent;

    XmlElement next = sib.nextSibling;
    while (next != null) {
      final laterNext = next.nextSibling;
      if (next.name.local == 'r') {
        parent.children.remove(next);
      }
      next = laterNext;
    }

    XmlElement prev = sib.previousSibling;
    while (prev != null) {
      final laterPrev = prev.previousSibling;
      if (prev.name.local == 'r') {
        parent.children.remove(prev);
      }
      prev = laterPrev;
    }
  }

  void updateRText(XmlElement r, String text) {
    final t =
        r.children.firstWhere((e) => e is XmlElement && e.name.local == 't');
    if (t != null) {
      t.children[0] = XmlText(text);
    }
  }
}

class PlainView extends View<PlainContent> {
  PlainView(ViewManager vm, XmlName name,
      [Iterable<XmlAttribute> attributesIterable = const [],
      Iterable<XmlNode> children = const [],
      bool isSelfClosing = true,
      String tag])
      : super(vm, name, attributesIterable, children, isSelfClosing, tag);
  @override
  List<XmlElement> produce(PlainContent c) {
    XmlElement copy = this.accept(vm._copyVisitor);
    var views = View.subViews(copy);
    for (var v in views) {
      vm._produceInner(c, v);
    }
    return List.from(copy.children);
  }

  @override
  PlainView createNew(XmlName name,
      [Iterable<XmlAttribute> attributesIterable = const [],
      Iterable<XmlNode> children = const [],
      bool isSelfClosing = true,
      String tag]) {
    return PlainView(
        vm, name, attributesIterable, children, isSelfClosing, tag);
  }
}

class ListView extends View<ListContent> {
  ListView(ViewManager vm, XmlName name,
      [Iterable<XmlAttribute> attributesIterable = const [],
      Iterable<XmlNode> children = const [],
      bool isSelfClosing = true,
      String tag])
      : super(vm, name, attributesIterable, children, isSelfClosing, tag);

  XmlElement _findFirstChild(XmlElement src, String name) => src
          .children.isNotEmpty
      ? src.children.firstWhere((e) => e is XmlElement && e.name.local == name)
      : null;

  XmlElement _getNumIdNode(XmlElement list) {
    if (list.children.isNotEmpty) {
      final e = list.children.first;
      if (e is XmlElement) {
        final pPr = _findFirstChild(e, 'pPr');
        if (pPr != null) {
          final numPr = _findFirstChild(pPr, 'numPr');
          if (numPr != null) {
            final numId = _findFirstChild(numPr, 'numId');
            return numId;
          }
        }
      }
    }
    return null;
  }

  String _getNewNumId(XmlElement list) {
    final numId = _getNumIdNode(list);
    if (numId != null) {
      final idNode = numId.getAttributeNode('val', namespace: '*');
      if (vm.numbering != null) {
        final newId = vm.numbering.copy(idNode.value);
        return newId;
      } else {
        return idNode.value;
      }
    }
    return '';
  }

  void _changeListId(XmlElement copy, String newId) {
    final numId = _getNumIdNode(copy);
    if (numId != null) {
      final idNode = numId.getAttributeNode('val', namespace: '*');
      numId.attributes.remove(idNode);
      numId.attributes.add(XmlAttribute(XmlName('val', 'w'), newId));
    }
  }

  @override
  List<XmlElement> produce(ListContent c) {
    List<XmlElement> l = [];
    if (c == null) {
      if (vm._viewStack.length >= 2 && vm._viewStack.elementAt(1) is RowView) {
        //

        final doc = XmlDocument.parse('''
        <w:p>
          <w:pPr>
            <w:pStyle w:val="TableContents"/>
            <w:rPr>
              <w:lang w:val="en-US"/>
            </w:rPr>
          </w:pPr>
          <w:r>
            <w:rPr>
              <w:lang w:val="en-US"/>
            </w:rPr>
            <w:t></w:t>
          </w:r>
        </w:p>
        ''');

        /* XmlElement copy = this.accept(vm._copyVisitor);
        var views = View.subViews(copy);
        for (var v in views) {
          vm._produceInner(null, v);
        } */
        l = [doc.rootElement];
      }
      /*  */
    } else {
      final vs = vm._viewStack;
      String newNumId;
      if (vs.any((element) => element is PlainView || element is RowView)) {
        newNumId = _getNewNumId(this);
      }
      for (var cont in c.list) {
        XmlElement copy = this.accept(vm._copyVisitor);

        if (newNumId != null &&
            vs.any((element) => element is PlainView || element is RowView)) {
          _changeListId(copy, newNumId);
        }

        var views = View.subViews(copy);
        for (var v in views) {
          vm._produceInner(cont, v);
        }
        if (copy.children != null) {
          l.addAll(copy.children.cast<XmlElement>());
        }
      }
    }
    return l;
  }

  @override
  ListView createNew(XmlName name,
      [Iterable<XmlAttribute> attributesIterable = const [],
      Iterable<XmlNode> children = const [],
      bool isSelfClosing = true,
      String tag]) {
    return ListView(vm, name, attributesIterable, children, isSelfClosing, tag);
  }
}

class RowView extends View<TableContent> {
  RowView(ViewManager vm, XmlName name,
      [Iterable<XmlAttribute> attributesIterable = const [],
      Iterable<XmlNode> children = const [],
      bool isSelfClosing = true,
      String tag])
      : super(vm, name, attributesIterable, children, isSelfClosing, tag);

  @override
  List<XmlElement> produce(TableContent c) {
    List<XmlElement> l = [];

    if (c == null) {
      XmlElement copy = this.accept(vm._copyVisitor);
      l = List.from(copy.children);
    } else {
      for (var cont in c.rows) {
        XmlElement copy = this.accept(vm._copyVisitor);
        var views = View.subViews(copy);
        for (var v in views) {
          vm._produceInner(cont, v);
        }
        if (copy.children != null) {
          l.addAll(copy.children.cast<XmlElement>());
        }
      }
    }
    return l;
  }

  @override
  RowView createNew(XmlName name,
      [Iterable<XmlAttribute> attributesIterable = const [],
      Iterable<XmlNode> children = const [],
      bool isSelfClosing = true,
      String tag]) {
    return RowView(vm, name, attributesIterable, children, isSelfClosing, tag);
  }
}
