class Credits {
  int? id;
  List<Cast>? cast;
  List<Crew>? crew;
  List<TVEpisodeGuestStars>? episodeGuestStars;

  Credits({this.id, this.cast, this.crew, this.episodeGuestStars});

  Credits.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    if (json['cast'] != null) {
      cast = [];
      json['cast'].forEach((v) {
        cast?.add(Cast.fromJson(v));
      });
    }
    if (json['crew'] != null) {
      crew = [];
      json['crew'].forEach((v) {
        crew?.add(Crew.fromJson(v));
      });
    }
    if (json['guest_stars'] != null) {
      episodeGuestStars = [];
      json['guest_stars'].forEach((v) {
        episodeGuestStars?.add(TVEpisodeGuestStars.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    if (cast != null) {
      data['cast'] = cast?.map((v) => v.toJson()).toList();
    }
    if (crew != null) {
      data['crew'] = crew?.map((v) => v.toJson()).toList();
    }
    if (episodeGuestStars != null) {
      data['guest_stars'] = episodeGuestStars?.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Cast {
  int? castId;
  String? character;
  String? creditId;
  int? gender;
  int? id;
  String? name;
  int? order;
  String? profilePath;
  String? department;
  List<Roles>? roles;
  bool? adult;

  Cast(
      {this.castId,
      this.character,
      this.creditId,
      this.gender,
      this.id,
      this.name,
      this.order,
      this.profilePath,
      this.department,
      this.roles,
      this.adult});

  Cast.fromJson(Map<String, dynamic> json) {
    castId = json['cast_id'];
    character = json['character'];
    creditId = json['credit_id'];
    gender = json['gender'];
    id = json['id'];
    name = json['name'];
    order = json['order'];
    profilePath = json['profile_path'];
    adult = json['adult'];
    department = json['known_for_department'];
    if (json['roles'] != null) {
      roles = [];
      json['roles'].forEach((v) {
        roles?.add(Roles.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['cast_id'] = castId;
    data['character'] = character;
    data['credit_id'] = creditId;
    data['gender'] = gender;
    data['id'] = id;
    data['name'] = name;
    data['order'] = order;
    data['profile_path'] = profilePath;
    data['known_for_department'] = department;
    data['adult'] = adult;
    if (roles != null) {
      data['roles'] = roles?.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Roles {
  String? character;
  int? episodeCount;
  Roles({this.character, this.episodeCount});
  Roles.fromJson(Map<String, dynamic> json) {
    character = json['character'];
    episodeCount = json['episode_count'];
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['character'] = character;
    data['episode_count'] = episodeCount;
    return data;
  }
}

class Crew {
  String? creditId;
  String? department;
  int? gender;
  int? id;
  String? job;
  String? name;
  String? profilePath;
  bool? adult;

  Crew(
      {this.creditId,
      this.department,
      this.gender,
      this.id,
      this.job,
      this.name,
      this.profilePath,
      this.adult});

  Crew.fromJson(Map<String, dynamic> json) {
    creditId = json['credit_id'];
    department = json['department'];
    gender = json['gender'];
    id = json['id'];
    // A series' combined credits list each person's jobs instead.
    job = json['job'] ??
        (json['jobs'] as List<dynamic>?)
            ?.map((entry) => (entry as Map<String, dynamic>)['job'])
            .whereType<String>()
            .join(', ');
    name = json['name'];
    adult = json['adult'];
    profilePath = json['profile_path'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['credit_id'] = creditId;
    data['department'] = department;
    data['gender'] = gender;
    data['id'] = id;
    data['job'] = job;
    data['name'] = name;
    data['profile_path'] = profilePath;
    data['adult'] = adult;
    return data;
  }
}

class TVEpisodeGuestStars {
  String? character;
  String? creditId;
  int? gender;
  int? id;
  String? name;
  int? order;
  String? profilePath;
  String? department;
  bool? adult;

  TVEpisodeGuestStars(
      {this.character,
      this.creditId,
      this.gender,
      this.id,
      this.name,
      this.order,
      this.profilePath,
      this.department,
      this.adult});

  TVEpisodeGuestStars.fromJson(Map<String, dynamic> json) {
    character = json['character'];
    creditId = json['credit_id'];
    gender = json['gender'];
    id = json['id'];
    name = json['name'];
    order = json['order'];
    profilePath = json['profile_path'];
    adult = json['adult'];
    department = json['known_for_department'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['character'] = character;
    data['credit_id'] = creditId;
    data['gender'] = gender;
    data['id'] = id;
    data['name'] = name;
    data['order'] = order;
    data['profile_path'] = profilePath;
    data['known_for_department'] = department;
    data['adult'] = adult;
    return data;
  }
}
