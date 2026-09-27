class Videos {
  List<Results>? result;

  Videos({
    this.result,
  });

  Videos.fromJson(Map<String, dynamic> json) {
    if (json['results'] != null) {
      result = [];
      json['results'].forEach((v) {
        result?.add(Results.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (result != null) {
      data['results'] = result?.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Results {
  String? name;
  String? videoLink;

  /// TMDB's kind of video ("Trailer", "Teaser", "Featurette") and where it
  /// is hosted ("YouTube").
  String? type;
  String? site;
  Results({this.name, this.videoLink, this.type, this.site});
  Results.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    videoLink = json['key'];
    type = json['type'];
    site = json['site'];
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['key'] = videoLink;
    if (type != null) data['type'] = type;
    if (site != null) data['site'] = site;
    return data;
  }
}
