import unittest
from unittest.mock import patch, MagicMock
import Resolver


class Sources(unittest.TestCase):
    def setUp(self):
        Resolver.cache.clear()

    def test_rejects_non_provider_before_network(self):
        for url in ['http://youtube.com/watch?v=x', 'https://127.0.0.1/x',
                    'https://youtube.com.evil.test/x', 'https://user:pass@youtube.com/x',
                    'https://youtube.com:8000/x']:
            with self.subTest(url=url), patch('Resolver.urllib.request.urlopen') as network:
                with self.assertRaises(ValueError): Resolver.resolve_source(url)
                network.assert_not_called()

    def test_rejects_untrusted_redirect(self):
        redirect = Resolver.ProviderRedirects()
        with self.assertRaises(ValueError):
            redirect.redirect_request(None, None, 302, '', {}, 'https://127.0.0.1/private')

    def test_youtube_resolution_and_cache(self):
        client = MagicMock()
        client.extract_info.return_value = {'formats': [
            {'protocol': 'm3u8_native', 'height': 720, 'vcodec': 'avc1.4d', 'url': 'https://cdn.example/live.m3u8'},
            {'protocol': 'm3u8_native', 'height': 1080, 'vcodec': 'avc1.4d', 'url': 'https://cdn.example/large.m3u8'}]}
        with patch('Resolver.yt_dlp.YoutubeDL') as factory:
            factory.return_value.__enter__.return_value = client
            url = 'https://www.youtube.com/embed/abcdefghijk'
            self.assertEqual(Resolver.resolve_source(url), 'https://cdn.example/live.m3u8')
            self.assertEqual(Resolver.resolve_source(url), 'https://cdn.example/live.m3u8')
            client.extract_info.assert_called_once_with('https://www.youtube.com/watch?v=abcdefghijk', download=False)

    def test_legacy_names_use_the_same_sources(self):
        with patch('Resolver.resolve_source', return_value='https://cdn.example/live.m3u8') as resolve:
            self.assertEqual(Resolver.resolve('lions'), 'https://cdn.example/live.m3u8')
            resolve.assert_called_once_with(Resolver.CAMERAS['lions'])


if __name__ == '__main__': unittest.main()
