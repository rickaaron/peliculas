import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:peliculas/helpers/debouncer.dart';
import 'package:peliculas/models/models.dart';
import 'package:peliculas/models/movie.dart';
import 'package:peliculas/models/now_play_response.dart';
import 'package:peliculas/models/search_movie_response.dart';

class MoviesProvider extends ChangeNotifier {
  final String _apiKey = '2181097dfb25c65ebd5cefdb24daced6';
  final String _baseUrl = 'api.themoviedb.org';
  final String _languaje = 'es--ES';

  List<Movie> onDisplayMovies = [];
  List<Movie> popularMovies = [];
  Map<int, dynamic> moviesCast = {};

  int popularPage = 0;

  final debounder = Debouncer(duration: Duration(milliseconds: 500));

  final StreamController<List<Movie>> _sugggestionStreamController =
      new StreamController.broadcast();

  Stream<List<Movie>> get suggestionStream =>
      this._sugggestionStreamController.stream;

  MoviesProvider() {
    getOnDisplayMovies();
    getPopularMovies();
  }

  Future<String> _getJsonData(String section, [int page = 1]) async {
    var url = Uri.https(_baseUrl, '$section', {
      'api_key': _apiKey,
      'languaje': _languaje,
      'page': '$page',
    });
    var response = await http.get(url);
    return response.body;
  }

  getOnDisplayMovies() async {
    final decodeData =
        NowPlayingResponse.fromJson(await _getJsonData('3/movie/now_playing'));
    onDisplayMovies = [...decodeData.results];
    notifyListeners();
  }

  getPopularMovies() async {
    popularPage++;
    final popRes = PopularResponse.fromJson(
        await _getJsonData('3/movie/popular', popularPage));
    popularMovies = [...popularMovies, ...popRes.results];
    notifyListeners();
  }

  Future<List<Cast>> getMovieCast(int movieId) async {
    if (moviesCast.containsKey(movieId)) return moviesCast[movieId];
    if (moviesCast[movieId] == null) {
      final castResponse = CreditsResponse.fromJson(
          await _getJsonData('3/movie/$movieId/credits'));
      moviesCast[movieId] = castResponse.cast;
    }
    return moviesCast[movieId];
  }

  Future<List<Movie>> searchMovies(String query) async {
    if (query.isNotEmpty) {
      print('geting movues');
      var url = Uri.https(_baseUrl, '3/search/movie', {
        'api_key': _apiKey,
        'languaje': _languaje,
        'query': '$query',
      });
      var response = await http.get(url);
      final searchResponse = SearchMovieResponse.fromJson(response.body);
      return searchResponse.results;
    }

    return [];
  }

  void getSuggestionByQuery(String searchTerm) {
    debounder.value = '';
    debounder.onValue = (value) async {
      print('Tenemos valor a buscar: $searchTerm');
      final results = await this.searchMovies(searchTerm);
      this._sugggestionStreamController.add(results);
    };

    final timer = Timer.periodic(Duration(milliseconds: 300), (_) {
      debounder.value = searchTerm;
    });

    Future.delayed(Duration(microseconds: 301)).then((value) => timer.cancel());
  }
}
